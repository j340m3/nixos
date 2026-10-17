# Knowledge vault — log

Append-only. One entry per ingest or query:

```
## [YYYY-MM-DD] ingest|query | <Title>
```

---

## [2026-10-16] ingest | Minimizing NixOS footprint (1 GB RAM / 10 GB disk) vs Alpine

Filed 9 source pages, 4 concept pages, 1 synthesis. Primary: siraben 91 MiB ISO
gist, natkr "NixOS but smol", local nixpkgs profiles + closure internals.
Conclusion: Alpine parity is impossible (glibc+systemd+kernel floor ≈100 MiB >
full Alpine install); highest-value rebuild-safe levers for `pricklepants` are
`perlless` profile, slim-systemd overlay, and firmware/`systemPackages` trim.

## [2026-10-16] query | Applying top-3 footprint levers to pricklepants

Attempted to apply the synthesis's top-3 to `pricklepants`. Measured: levers
`environment.defaultPackages = []` and `hardware.enableRedistributableFirmware
= false` are ALREADY satisfied (both set by `profiles/minimal.nix`, which the
host imports). Tried `profiles/perlless.nix`: built the toplevel, the
`forbiddenDependenciesRegexes = ["perl"]` assertion failed with ~51 perl
paths in the closure. Reverse-dep scan (`closure-info` + `nix-store -q
--references`) found the sole inbound edge is `git` (git-2.55.0 → perl5.42.x).
`git` is added to all hosts by `modules/common/update.nix:31-33`. Reverted the
perlless import + the GRUB override it needed. Remaining real lever = slim
systemd overlay (~130 MiB), not yet applied. Recorded in
`concepts/profile-based-slimming` + synthesis.
