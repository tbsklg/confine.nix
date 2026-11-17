"""Drives one CONNECT tunnel through the proxy: `tunnel.py <proxy port> <target> echo|early|greet`.

echo:  sends 1 MiB after the 200, expects the same 1 MiB back.
early: sends the CONNECT head and the first bytes in one write, expects them back.
greet: sends nothing, expects the upstream's "hello\n".
hold:  opens the tunnel, prints "open", then keeps it idle until killed.
late:  like early, but waits 12 s after the 200 before sending.
stall: sends half a head, prints after how many seconds the proxy hung up.
Prints "ok" or what went wrong; exit status 0 only on "ok".
"""
import os
import socket
import sys

proxy_port, target, mode = int(sys.argv[1]), sys.argv[2], sys.argv[3]
head = f"CONNECT {target} HTTP/1.1\r\nHost: {target}\r\n\r\n".encode()


def fail(message):
    print(message)
    sys.exit(1)


def read_head(sock, buffered=b""):
    while b"\r\n\r\n" not in buffered:
        chunk = sock.recv(4096)
        if not chunk:
            fail(f"connection closed before the end of the response head: {buffered!r}")
        buffered += chunk
    response, rest = buffered.split(b"\r\n\r\n", 1)
    status = response.split(b"\r\n", 1)[0].decode(errors="replace")
    if status != "HTTP/1.1 200 Connection Established":
        fail(f"response: {status}")
    return rest


def read_all(sock, received):
    while chunk := sock.recv(65536):
        received += chunk
    return received


sock = socket.create_connection(("127.0.0.1", proxy_port), timeout=5)
try:
    if mode == "echo":
        sock.sendall(head)
        received = read_head(sock)
        payload = os.urandom(1024 * 1024)
        sock.sendall(payload)
        sock.shutdown(socket.SHUT_WR)
    elif mode == "late":
        import time
        sock.settimeout(30)
        sock.sendall(head)
        received = read_head(sock)
        time.sleep(12)
        payload = b"still here\n"
        sock.sendall(payload)
        sock.shutdown(socket.SHUT_WR)
    elif mode == "early":
        payload = b"bytes that arrive together with the head\n"
        sock.sendall(head + payload)
        received = read_head(sock)
        sock.shutdown(socket.SHUT_WR)
    elif mode == "stall":
        import time
        started = time.monotonic()
        sock.settimeout(30)
        sock.sendall(head.split(b"\r\n", 1)[0] + b"\r\n")
        while sock.recv(4096):
            pass
        print(round(time.monotonic() - started))
        sys.exit(0)
    elif mode == "hold":
        sock.sendall(head)
        read_head(sock)
        print("open", flush=True)
        sock.settimeout(None)
        sock.recv(1)
        sys.exit(0)
    elif mode == "greet":
        sock.sendall(head)
        received = read_head(sock)
        payload = b"hello\n"
        while len(received) < len(payload):
            chunk = sock.recv(64)
            if not chunk:
                break
            received += chunk
        print("ok" if received == payload else f"expected {payload!r}, got {received!r}")
        sys.exit(0 if received == payload else 1)
    received = read_all(sock, received)
except socket.timeout:
    fail("timed out waiting for the tunnel")
except OSError as err:
    fail(f"socket error: {err}")

if received != payload:
    fail(f"sent {len(payload)} bytes, got {len(received)} back" + ("" if len(received) != len(payload) else " (different bytes)"))
print("ok")
