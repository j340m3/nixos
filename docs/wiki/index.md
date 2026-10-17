# Knowledge vault — index

Catalog of compiled knowledge for this repo. Read this first; one line per page.
Pages live in `sources/` (one per raw source), `concepts/` (compiled notes per
topic/library), and `syntheses/` (cross-source answers). `log.md` is append-only.

## Pages

### syntheses
- `syntheses/nixos-footprint-vs-alpine.md` — ranked levers to shrink a NixOS host, irreducible floor vs Alpine, top 3 for `pricklepants`.

### concepts
- `concepts/nixos-closure-levers.md` — what dominates closure size + measurement commands + ordered cuts.
- `concepts/nix-store-disk-control.md` — GC, generations, auto-optimise, min/max-free, journal bounds.
- `concepts/ram-footprint.md` — zram tuning, oomd vs earlyoom, build-time RAM bounds.
- `concepts/profile-based-slimming.md` — minimal/headless/perlless/bashless/image-based-appliance; rebuildability trade-offs.

### sources
- `sources/siraben-smallest-iso.md` — smallest bootable NixOS ISO (~91 MiB), per-lever results.
- `sources/natkr-nixos-but-smol.md` — 458→183 MiB ISO; `nix why-depends`, kernel modules, perl removal.
- `sources/nixpkgs-minimal-profiles.md` — `nixos/modules/profiles/*` (minimal/headless/perlless/bashless/image-based-appliance).
- `sources/nixpkgs-corepackages-toplevel.md` — core/default packages, `/etc` overlay, userborn, oomd, zram, `nix.gc`.
- `sources/nixcademy-minimizing-images.md` — appliance image 1.5 GB → 362 MB.
- `sources/rafael-minimal-closure.md` — minimal appliance closure ≈467.7 MiB; systemd 166 / kernel 129.66.
- `sources/discourse-nix-store-bloat.md` — store 3.5 GB → 2.0 GB after `nix-collect-garbage -d`.
- `sources/discourse-storage-requirements.md` — storage budgeting; two-closure rule.
- `sources/alpine-linux.md` — Alpine ≤8 MB container / ~130 MB install; musl+BusyBox baseline.

## Orientation (not vault pages)

Durable knowledge that already lives elsewhere in this repo:

- `docs/adr/` — architecture decisions (ADR-0000..0011), indexed by `docs/adr/README.md`.
- `docs/superpowers/specs/` — designs; `docs/superpowers/plans/` — implementation plans.
- `docs/secrets-101.md`, `docs/superpowers/identity-keys.md` — secrets/identity how-to.
- `HOSTS.md` — host inventory; `README.md` — repo entry point.
- `scripts/` — `wireguard-peers.py`, `rotate-secrets.py`, `publish-host-keys.py`.

## Conventions

- Status line per page: `current` / `stale as of <date>` / `superseded by <page>`.
- Cite the `sources/` page for each claim; never silently overwrite a
  contradicting claim — add a `> CONTRADICTION:` block.
- Every page is listed here; no orphan pages.
