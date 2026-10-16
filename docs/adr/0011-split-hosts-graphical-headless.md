# ADR-0011: Split hosts/ into graphical and headless classes

**Date**: 2025-10-07
**Status**: accepted (backfilled 2026-10-15)
**Deciders**: j340m3

## Context

Auto-discovery (ADR-0001) put every host in one flat `hosts/` folder. The
fleet mixes desktops/laptops with servers, VPSes, and provisioning images;
the flat list made the class of a host visible only by reading its config.

## Decision

Split into `hosts/graphical/` and `hosts/headless/`. Each subdirectory is
auto-discovered the same way; the folder name remains the host name. The
README and `HOSTS.md` describe the split.

## Alternatives Considered

### Keep a flat hosts/ with class as metadata
- **Pros**: one discovery loop; class recorded elsewhere (e.g. comments).
- **Cons**: class not visible in the tree; easy to ignore.
- **Why not**: directory listing is the cheapest classifier.

### Encode class in host config (option) instead of path
- **Pros**: class drives behaviour, not just grouping.
- **Cons**: nothing consumes a class option today; path grouping is enough.
- **Why not**: YAGNI until something needs to iterate over "all graphical"
  or "all headless" hosts.

## Consequences

### Positive
- `ls hosts/` tells you the fleet shape at a glance.
- Per-class conventions (e.g. bootstrap images, WSL) live in one place.

### Negative
- A host whose class changes requires a folder move (rename in git), not
  just a config edit.
