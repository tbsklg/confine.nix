# 8. Logs go to the macOS unified log

Date: 2026-10-29
Status: Accepted

## Context

A program that fails under the sandbox usually fails because something was denied, and the user has to find out what.

## Decision

Sessions, broker calls and the sandbox's denials go to the macOS unified log, under the subsystem `tbsklg.confine`.

## Consequences

- One place to look, with the system's own tools: `log stream`, Console.
- No log files to rotate or protect.
