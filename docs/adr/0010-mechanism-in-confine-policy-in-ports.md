# 10. Mechanism in confine, policy in confine-ports

Date: 2026-11-09
Status: Accepted

## Context

Presets, gateways and adapters change far more often than the launcher, and they were released together with it.

## Decision

Presets, gateways and adapters move to [confine-ports](https://github.com/tbsklg/confine-ports) and update on their own. confine keeps the launcher, the broker, `mkSandboxEnv` and `mkGateway`. Preset rules stay plain data.

## Consequences

- A new preset doesn't need a confine release, and confine changes don't touch policy.
- An env pins both and updates them together.
- Rejected: a helper layer for preset rules, tried and dropped as less clear than plain data.
