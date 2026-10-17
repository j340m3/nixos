---
title: Minimizing NixOS images — nixcademy
url: https://nixcademy.com/posts/minimizing-nixos-images/
kind: secondary
accessed: 2026-10-16
---

# nixcademy — minimizing NixOS images

Reported (secondary; numbers as published): building a systemd-repart-based
appliance image, a **raw image of ~1.5 GB shrank to ~362 MB**. The approach is
the appliance workflow: `image-based-appliance` profile + `nix.enable = false` +
`system.switch.enable = false`, plus repart/sysupdate for updates.

Takeaway: the big win on *images* is dropping Nix, switch-to-configuration and
the package set the user never runs — not micro-tuning individual packages.
