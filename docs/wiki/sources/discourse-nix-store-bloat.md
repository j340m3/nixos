---
title: Disk usage of the Nix store ("speaking of bloat") — NixOS Discourse
url: https://discourse.nixos.org/t/disk-usage-for-nix-store-speaking-of-bloat/
kind: secondary
accessed: 2026-10-16
---

# NixOS Discourse — Nix store disk usage ("speaking of bloat")

Reported (secondary). A user's store was **3.5 GB before `nix-collect-garbage -d`,
2.0 GB after** — i.e. generations/old paths are often the *majority* of store
usage, not the current closure.

Takeaway: on a small-disk host, garbage collection cadence and generation limits
(`boot.loader.*.configurationLimit`) frequently free more than any packaging
change. `nix.gc.automatic` + `-d` is the lever (see `nixpkgs-corepackages-toplevel`).
