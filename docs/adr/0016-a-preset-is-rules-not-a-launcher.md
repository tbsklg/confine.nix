# 16. A preset is rules, not a launcher

Date: 2026-11-11
Status: Accepted

## Context

A preset named its program, `binary` and `args`, and `confine-<name>` started it. Running anything else in the same sandbox meant a second env.

## Decision

A preset is the rules and packages a program needs, plus `setEnv`. `confine-<name>` runs the command you name, or a shell. Startup args go into a wrapper script.

## Consequences

- The tool confines; it doesn't decide what runs.
- Users type the program's name: `confine-dev claude`.
