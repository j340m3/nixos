---
title: A NixOS system with a 100k closure — rafael.ovh
url: https://rafael.ovh/posts/nixos-system-100k-closure-size/
kind: secondary
accessed: 2026-10-16
---

# rafael.ovh — small closure measurement

Reported (secondary). A configuration combining `minimal` +
`image-based-appliance` + `perlless` yields a closure of **≈467.7 MiB**
(mentions a "100k closure size" in the title — read as closure *entry count*
vs MiB; treat the MiB figure as the relevant one).

Biggest contributors reported:
- **systemd ≈ 166 MiB** (full systemd, not slim)
- **kernel ≈ 129.66 MiB**

Takeaway: on a non-ISO system the two dominant irreducibles are the kernel and
systemd; slimming systemd via overlay is the single largest *achievable* cut
(siraben gets it to ~35 MiB).
