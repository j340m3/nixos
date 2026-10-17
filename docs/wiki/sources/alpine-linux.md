---
title: Alpine Linux — size and design
url: https://www.alpinelinux.org/about/
kind: primary
accessed: 2026-10-16
---

# Alpine Linux — baseline for "small"

Alpine is the comparison point for NixOS slimness. Reported figures:
- Alpine container base image **≤ 8 MB**.
- Typical disk install **~130 MB** (also reported ~130 MB in community docs; the
  Alpine virt ISO is ~66 MB per `natkr-nixos-but-smol`).
- Design: musl libc + BusyBox (multi-call binary) instead of glibc + GNU coreutils;
  OpenRC/s6 rather than systemd.

Takeaway: NixOS cannot reach Alpine numbers without replacing glibc+systemd+bash
— the x86_64-linux closure floor from those three alone exceeds a full Alpine
install. NixOS "slim" means 90 MiB–500 MiB, not 8 MB.
