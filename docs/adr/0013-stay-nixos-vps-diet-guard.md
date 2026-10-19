# ADR-0013: Stay NixOS on the 10G disk VPS, diet the closure instead

**Date**: 2026-10-19
**Status**: accepted
**Deciders**: jeromeb + sizing session (grilling)

## Context

pricklepants holds the densest workload set (vaultwarden, luanti, wireguard,
nebula lighthouse, remote-builder, yggdrasil) on a 10GiB Ionos disk with a
9G root partition. It had filled up in the past to the point of failed
rebuilds. The invariant that rules this fleet is ADR-0000's update
independence: every host must be able to pull its next generation from this
repo and switch to it in place. A transient nixpkgs bump needs the new and
the old closure on the same disk at once, so the comfortable target is 2x
closure-size of free headroom.

Campus-level alternatives exist at a fraction of the footprint:

- **liminix** — musl/busybox/s6-rc router OS, tens of MB by design. No
  x86_64 target; updates are push-based `min-copy-closure`, no generations.
- **sixos** — Adam Joseph's nixpkgs-free NixOS flavor. No published
  footprint figures, no in-place self-update path.
- **not-os** — 47-48MiB squashfs, real module system, but
  `systemd.services` is silently stubbed and there is no users module;
  updates mean re-imaging or signed-iPXE.

## Decision

Stay with NixOS for the VPS class and reclaim the headroom by:
1. replacing the client luanti binary the minetest-server module ships with
   the dedicated `pkgs.luanti-server` (module hardcodes `pkgs.luanti`,
   whose closure drags sdl2-compat → sdl3 → zenity → gtk4 →
   gst-plugins-bad → flite onto a headless host),
2. disabling root's legacy nix-channel state on every host and removing
   the stale profile links on switch, which un-roots the old 24.11 eval
   tree (~430MiB) so hourly GC can collect it,
3. a remediate-then-fail-loud disk guard as `nixos-upgrade`
   `ExecStartPre`: measure free space on /nix; when under 4GiB run the
   remediation the hourly GC would do anyway (collect unreachable store
   paths, vacuum the journal) and re-measure; fail the unit only if even
   that cannot make room. `onFailure` → notify-telegram reports it, the
   next hourly attempt retries.

Closure after the diet: 2.2 GiB (was 2.8 GiB), worst case ~5.5G of 8.7G
with both generations staged → ~2.5G margin against the 2x criterion.

## Alternatives Considered

### Alternative 1: fork not-os into a minimal self-updating VPS OS
- **Pros**: 47-48MiB squashfs; fun systems project.
- **Cons**: no switch/activate/rollback story, no users module, sops
  secrets would need porting; all seven workloads are hand-run services.
- **Why not**: fails the update-independence invariant as-is. Kept as a
  side project, kickoff brief in the sibling repo
  `~/code/github/not-os-experiment/HANDOFF.md` (outside this repository).

### Alternative 2: custom kernel + slim systemd overlay
- **Pros**: ~130MiB more; custom kernel trims the module set.
- **Cons**: high maintenance against 26.11, plain kernel modules redefine
  mentioned model instability; slim systemd breaks documented features
  (systemd-networkd timers, tmpfiles, trap).
- **Why not**: cost/benefit poor at 2.2GiB closure.

### Alternative 3: grow the disk
- **Pros**: zero code.
- **Cons**: cost per month; treats the symptom, not the design.
- **Why not**: the diet was achievable and the guard makes future short
  disks loud instead of silent.

## Consequences

### Positive
- Measured 2.2GiB closure; the disk-fill failure mode of the past is
  bounded by the remediation-first guard.
- The minetest service explains its own binary choice in one config line.

### Negative
- `luantiserver` rejects `--server`, so the ExecStart override drops
  that flag; a future minetest-server module gaining a `package` option
  should shrink this override to one option line.
- The disk guard runs on every autoUpgrade host; a host whose /nix is
  ground down below 4GiB stops upgrading until GC frees space.

### Risks
- All host configs now `nix.channel.enable = false`; any host that starts
  depending on `<nixpkgs>` or root's channels loses that silently — repo
  greps confirmed nothing does today.
