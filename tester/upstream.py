"""Test upstream for the proxy tester: `upstream.py <port> echo|greet`.

echo:  sends back everything it receives, then closes once the client has.
greet: says "hello\n" as soon as a client connects, then behaves like echo.
"""
import socket
import socketserver
import sys

port, mode = int(sys.argv[1]), sys.argv[2]


class Handler(socketserver.BaseRequestHandler):
    def handle(self):
        if mode == "greet":
            self.request.sendall(b"hello\n")
        while data := self.request.recv(65536):
            self.request.sendall(data)
        self.request.shutdown(socket.SHUT_WR)


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


Server(("127.0.0.1", port), Handler).serve_forever()
