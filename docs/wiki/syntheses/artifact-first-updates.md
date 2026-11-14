# Artifact-first updates (2026-11-13)

Question that opened the grilling session: *"Some of my hosts have trouble
rebuilding due to memory pressure. What can we do to alleviate this without
compromising on the independence?"* Answer recorded in
[ADR-0018](../../docs/adr/0018-artifact-first-updates.md).

## The diagnosis

- **pricklepants** (1 GB/10 GB, vaultwarden + luanti): every update pays a
  full flake eval *on the box*, and it inherited `max-jobs = 6` from the
  remote-builder aspect — six parallel local builds whenever the builders
  were dark. The 2026-11-07 thrash incident is the reference case.
- **jessie** (1-core/1.8 GB, minecraft + radicle): same eval bill; its
  `zramSwap.enable = false` was a leftover of the long-gone tmpfs-era `/`.
- **slinky's kernel was never cacheable**, for four compounding reasons:
  harmonia serves woody's `/nix/store` and *nothing ever writes into it*
  (no `nix copy` in the whole repo history); fleet builder entries carried
  no `supportedFeatures` while the kernel demands `big-parallel`; slinky's
  `builder-local` machine entry lost its ssh alias in commit `425c717` and
  silently fell back to local; the public uConsole cache publishes a
  different kernel entirely (oom-hardware 6.6.51 vs nixos-hardware 6.18.50).

## The design (decided in grilling, 12 questions)

An **artifact-first split**: the eval+build work moves to the host with
headroom (woody, which already evals the whole flake hourly for its own
autoUpgrade), the memory-starved hosts only *download and switch*.

- `modules/services/artifact-publisher.nix` (woody): hourly :25, builds
  pricklepants/jessie/slinky toplevels from `github:j340m3/nixos`, one
  latest-only GC root per host under `/var/lib/artifact-publisher/roots/`,
  manifest.json regenerated from the surviving links, served by nginx on
  woody's nebula IP :5001 (mesh-only, plain HTTP — the client's signature
  check is the real boundary), 6G min-free space guard, Telegram on
  failure. Building slinky's toplevel drops its aarch64 kernel into
  woody's store — which *is* harmonia — closing the kernel-caching gap as
  a byproduct.
- `modules/system/artifact-update.nix` (pricklepants + jessie): hourly
  :05, validates the manifest entry is a `/nix/store/*-nixos-system-*`
  path, applies each distinct closure **at most once** (state file; manual
  rebuilds win, stale manifests cannot clobber), `nix-store -r` →
  `nix-env --set` → `switch-to-configuration switch`.
- **Fallback everywhere**: the nixos-upgrade timer is disabled but the unit
  stays; the client's `OnFailure` starts it. Manifest dark ⇒ old hourly
  eval path. This is the ADR-0000 bar made mechanical: the artifact path
  is an accelerator, the self-update path is untouched.
- The health-check safety net is preserved: `onSuccess` arms
  `nixos-upgrade-health-schedule` where `upgradeHealth` is on.

## Host tuning bundled with the decision

- pricklepants: `max-jobs = mkForce 1` + idle daemon scheduling; swap
  encryption dropped (per-boot random key already bounds exposure; the
  decrypt tax paid during thrash was pure loss).
- jessie: zram re-enabled at 50%, ahead of the 4G swapfile.
- Builder roster (`_constants.nix`): buzz/mrpotatohead/woody advertise
  `big-parallel` + aarch64 (binfmt already armed); pricklepants/jessie
  stay featureless — a kernel build *on them* is the bug, not the fix.
  slinky's dead `builder-local` entry deleted.

## Known limitations (watch these)

- ~~No auto-reboot in the artifact path~~ (resolved 2026-11-14): a client
  now reboots for a staged kernel via `artifact-update-reboot` — only inside
  the reused `system.autoUpgrade.rebootWindow` (22:00–08:00), and only for
  kernels staged during the current uptime (`artifact-update-boot-state`
  writes the baseline into tmpfs `/run`, so a deliberate boot into a
  previous boot entry is never overridden; missing baseline = skip).
- slinky's toplevel *eval* still hits the pre-existing IFD wall
  (`dtbs-filtered`), which is why `just check` keeps skipping it — the
  publisher *builds* it, which is where that cost belongs.
- The manifest carries no trust: a mesh peer could serve a manifest
  pointing at an older *signed* closure; the at-most-once guard turns a
  downgrade into a one-shot. Cert-gated mesh membership is the accepted
  boundary.
- woody disk: one aarch64 closure (~5–15G unique) against ~17G free; the
  minFree guard fails loudly before it can starve woody's own upgrades,
  and slinky leaves `artifactPublisher.hosts` in one line if it strains.
