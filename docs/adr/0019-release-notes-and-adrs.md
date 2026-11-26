# 19. Release notes and ADRs instead of a changelog

Date: 2026-11-26
Status: Accepted

## Context

`CHANGELOG.md` mixed what changed with why, and `docs/upgrade.md` held what users had to do. A user reading about one version had to read both; the reasoning was buried in dated entries.

## Decision

What changed goes in [release notes](../release-notes/README.md), one page per version, like Apple's: per area, New Features, Resolved Issues, Known Issues and Deprecations. What users must change goes under Deprecations. Why goes in an ADR here, one per decision, never rewritten; a new ADR supersedes an old one.

## Consequences

- One page per version for users, one file per decision for the reasoning.
- A change that is a decision ships with its ADR.
