---
title: How much storage does NixOS need? — NixOS Discourse
url: https://discourse.nixos.org/t/how-much-storage-does-nixos-need/8805
kind: secondary
accessed: 2026-10-16
---

# NixOS Discourse — storage requirements

Reported (secondary). Community rule-of-thumb figures for installations:
a minimal NixOS system comfortably fits in single-digit GB; 10 GB is workable
for a small server but tight once multiple generations + a build closure coexist.
Nix's copy-on-write store means a rebuild needs room for the **new** closure
beside the old one.

Takeaway: budget for two closures plus GC headroom; this is why `min-free`/
`max-free` (collect mid-build) matter on a 10 GB disk.
