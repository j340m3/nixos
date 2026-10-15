# docs/

Documentation for this NixOS/home-manager flake.

## Index

- [Architecture Decision Records](./adr/) - Numbered ADRs for significant technical decisions (index in [adr/README.md](./adr/README.md)).
- [Analysis: nix-book improvements](./analysis-nix-book-improvements.md) - What ideas from nix-book are worth applying to this repo (ranked list with pros/cons/effort).
- [Secrets 101](./secrets-101.md) - sops-nix workflow, helper scripts (`publish-host-keys.py`, `rotate-secrets.py`), age key handling, safety rules.
- [Disks](./disks.md) - Disk layouts/filesystems per host (from hardware-configuration + disk setup notes).
- [Superpowers](./superpowers/) - Specs, plans, identity keys reference used by the superpowers workflow.
  - [identity-keys.md](./superpowers/identity-keys.md)
  - [plans/](./superpowers/plans/)
  - [specs/](./superpowers/specs/)
- [Hosts overview](../HOSTS.md) - High-level view of all hosts.
- [Root README](../README.md) - Flake layout, quick start, workflows.

## Learning Nix

- [nix-book (saylesss88)](https://saylesss88.github.io/) - The teaching mdBook this repo drew ideas from.
- [nix.dev](https://nix.dev/) - Official Nix documentation/guides.
- [NixOS Manual](https://nixos.org/manual/nixos/stable/) - NixOS configuration manual.
- [Nixpkgs Manual](https://nixos.org/manual/nixpkgs/stable/) - Nixpkgs reference.
