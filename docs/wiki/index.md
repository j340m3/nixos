# Wiki index

- [MPTCP CVEs 2025](sources/mptcp-cves-2025.md)
- [MPTCP defaults/check/disable](concepts/mptcp-defaults-check-disable.md)
- [MPTCP repo assessment](syntheses/mptcp-repo-assessment.md)

## Dendritic Pattern adoption (flake-parts)

Purpose: gathered knowledge for migrating the NixOS flake at the repo root to
the [Dendritic Pattern](https://github.com/mightyiam/dendritic) with
[flake-parts](https://flake.parts), per Doc-Steve's guide.

### Orientation

- The pattern in one line: *every Nix file (except `flake.nix`/entry points)
  is a top-level (flake-parts) module that implements one feature across all
  contexts; hosts/users/tools are features too; lower-level modules
  (NixOS/HM/darwin) are option values in the top-level config.* Sources:
  [dendritic-pattern](sources/dendritic-pattern.md) (canonical), FAQ in
  [doc-steve-guide](sources/doc-steve-guide.md).
- Framework: flake-parts provides `mkFlake`, `perSystem`/`systems`,
  `withSystem`, and the class-typed `flake.modules` option
  ([flake-parts](sources/flake-parts.md)).
- Auto-import: `import-tree` imports `.nix` files recursively and skips
  `/_`-prefixed paths ([import-tree](sources/import-tree.md)); optional
  `flake-file` regenerates flake.nix from per-feature input declarations —
  deep-dive in [flake-file](sources/flake-file.md)
  (`flakeModules.dendritic` internals, input syntax, regen loop, lockfile
  safety).

### Notes by task

- Writing features → [aspects](concepts/aspects.md) (8 aspect patterns with
  code sketches).
- Declaring hosts → [host-definition](concepts/host-definition.md) (the
  `mkNixos` + per-host `flake-parts.nix` + host-as-feature trio, plus
  mightyiam/infra and drupol/infra variants).
- Home-manager (embedded per-user, sharedModules, standalone) →
  [multi-context-home-manager](concepts/multi-context-home-manager.md).
- Planning THIS repo's migration →
  [migration-plan-notes](syntheses/migration-plan-notes.md) (mapping table of
  flake.nix/modules → dendritic targets, risks: aarch64 slinky, standalone HM
  pkg config, pre-commit, disko images, sops data dir, double imports).
- Settled plan (grilling 2026-10-21, ADR-0014) →
  [adopted-plan](syntheses/adopted-plan.md) (target tree, flake-file
  workflow, per-host conversion recipe).

### Sources

1. [mightyiam/dendritic](sources/dendritic-pattern.md) — canonical definition
   + anti-patterns.
2. [Doc-Steve guide](sources/doc-steve-guide.md) — Basics / Dendritic_Aspects
   / Comprehensive_Example / FAQ, example-repo findings.
3. [flake.parts](sources/flake-parts.md) — mkFlake, perSystem, systems,
   module arguments, flake.modules.
4. [import-tree](sources/import-tree.md) — upstream helper; local copy diff.
5. [flake-file](sources/flake-file.md) — denful/flake-file deep-dive: option
   schema (`flake-file.inputs.*`), `flakeModules.dendritic` internals,
   write-flake/check-flake-file loop, flake.lock non-invasiveness, Dendrix
   property list.

Glossary quick-link: repo-root [GLOSSARY.md](../../../GLOSSARY.md) defines
Image, Installed footprint, Update independence (repo vocabulary, not wiki
vocabulary).

## Reticulum transport node research (pricklepants)

Research vault for running a well-connected, always-on Reticulum transport
node on a public VPS, applied to `pricklepants` (Ionos). Compiled 2026-10-19
against RNS 1.5.5 (installed) and 1.5.7 (latest). Research only — no Nix
configuration was modified.

### Bottom line

Enable transport, publish a discoverable `BackboneInterface` gateway on TCP,
keep discovery learning on but set `autoconnect_discovered_interfaces = 0`,
raise `required_discovery_value` from 1 to 16, and prune the 23 static peers
to 3–5 verified links. Full config in the
[synthesis](syntheses/pricklepants-transport-node.md).

### Questions and where they are answered

| # | Question | Short answer | Page |
|---|---|---|---|
| 1 | Enable transport on this host? | Yes — stationary, always-on, public IP, bandwidth-rich; that is the manual's profile. | [transport nodes](concepts/transport-nodes.md) |
| 2 | Discoverable vs discover, thresholds, autoconnect | Publish the listener; keep learning for visibility; value 16 (not 1); no autoconnect on a public hub. | [interface discovery](concepts/interface-discovery.md) |
| 3 | VPS caveats | Open the TCP port, no TLS, CPU cost of announce verification, `listen(1)` backlog, drop AutoInterface. | [public node operations](concepts/public-node-operations.md), [backbone interface](concepts/backbone-interface.md) |
| 4 | Topology and redundancy | Few strategically placed transport nodes; several redundant backbone links; simple topology. | [transport nodes](concepts/transport-nodes.md) |
| 5 | Etiquette and abuse | Announce-rate limits, stamp discipline, blackhole lists, IFAC only for closed networks. | [public node operations](concepts/public-node-operations.md) |
| 6 | Recommended `[reticulum]` settings | See the concrete block and rationale. | [synthesis](syntheses/pricklepants-transport-node.md) |

### Pages

Sources:

- [RNS 1.5.7 source](sources/rns-1.5.7-source.md) — PyPI sdist provenance,
  verified code facts with file:line, 1.5.5 → 1.5.7 delta.
- [Reticulum manual](sources/reticulum-manual.md) — official chapters, quotes,
  doc/code contradictions.
- [Community resources](sources/community-resources.md) — rns.recipes field
  reports, community wiki, directories.
- [Pricklepants config](sources/pricklepants-config.md) — current
  `reticulum.conf` and module firewall, read 2026-10-19.

Concepts:

- [Transport nodes](concepts/transport-nodes.md) — what `enable_transport`
  does, when (not) to use it, topology, capacity.
- [Interface discovery](concepts/interface-discovery.md) — publishing vs
  learning, stamps, autoconnect, version differences.
- [Backbone interface](concepts/backbone-interface.md) — listener/client
  config, gateway mode, fast flapping, `listen(1)` caveat.
- [Public node operations](concepts/public-node-operations.md) — firewall,
  load, abuse, privacy controls, monitoring, etiquette.

Synthesis:

- [Pricklepants as a public transport node](syntheses/pricklepants-transport-node.md)
  — recommended config, peer pruning, firewall changes, verification, version
  flags.

### Open uncertainties

- `discovery_stamp_value` default: manual says 14, code says 16 (changelog
  records the 1.4.0 change). Code treated as authoritative.
- 1.5.6/1.5.7 have no upstream changelog in the public mirror; differences
  were established by diffing 1.5.5 against the 1.5.7 sdist.
- The `listen(1)` backlog and single-thread announce verification are
  confirmed in code / one field report, but there is no official fix or
  guidance yet.
- IPv4/IPv6 binding behaviour of `listen_on = ::` is reported inconsistently
  by community sources.
- Live peer and directory availability was not verifiable:
  `directory.rns.recipes` returned no entries at capture time.

## rnsh security audit (2026-11-13)

Security-audit groundwork for "borg backup over RNS via rnsh" and the question
of switching away from the *archived* rnsh GitHub repos. Applies to woody's
`rnsh-nix` / `rnsh-borg` listeners and the shared instance.

**Bottom line:** no switch. The deployed rnsh is a Mark-Qvist rewrite bundled
in the `rns` package (RNS/Utilities/rnsh) — first-party and maintained; the
archived repos are the superseded acehoss original. `-C` hard-restricts
execution to the listener's fixed command, `-a` is cryptographic (LINKIDENTIFY
signature + hash-pinned key), and the server is authenticated by the link
proof. `rpc_key` protects only the shared instance's local control-plane RPC;
on Linux the actual channels are abstract sockets `@rns/default(+/rpc)` unless
`shared_instance_type = tcp` (configured ports inert). No CVEs for RNS/rnsh;
RNS Links give forward secrecy and initiator anonymity by construction.

- Questions/answers: [rnsh retirement audit](syntheses/rnsh-retirement-audit.md)
- Listener + `-a`/`-C` semantics with file:line:
  [rnsh listener security](concepts/rnsh-listener-security.md)
- Sources: [bundled rnsh vs archived repos](sources/rnsh-bundled-rnsh.md),
  [shared instance + rpc_key](sources/rns-shared-instance-rpc.md),
  [Rust implementations / rsReticulum](sources/rust-reticulum-implementations.md),
  [advisories + Link threat model](sources/rns-advisories-and-threat-model.md)
- Open item flagged for the host: confirm/decide the AF_UNIX-vs-TCP
  shared-instance binding (`shared_instance_type` unset on woody).

### Fixes implemented (2026-11-13, ADR-0017)

The adversarial audit of the borg-over-RNS machinery found six findings
(F1–F6); all were fixed and committed, eval-verified per host:

- F1 rnsh-borg scoped to pricklepants' repo only (`42f1e78`);
- F2 rpc_key now a random per-host sops secret rendered at boot, template +
  `/run/reticulum/config`, no secret in the store, fail-closed (`393341d`);
- F3 group split reticulum/rnsh-borg, identities isolated per listener
  (`530b98b`);
- F4 rnsh-nix allowlist = actual remote builders only (`f8bcfcc`);
- F5/F6 unprivileged sandboxed rnsd + hardened listeners
  (`fb33dd5`).

Accepted/deferred by owner: repos stay unencrypted until the NAS/offsite
(rclone crypt) leg; rsReticulum not adopted; `BORG_RSH` nebula rollback kept.
Decision record: [ADR-0017](../../docs/adr/0017-harden-borg-over-reticulum.md).
Deployment gate: every reticulum host needs `["rpc_key"]` in
`secrets/hosts/<host>/reticulum.yaml` before rebuild (fail-closed by design).

## Nix/NixOS recent developments (2024–2026)

Purpose: orientation on recent Nix/NixOS changes worth considering for a user.

### Pages

Sources:

- [NixOS 26.05 release notes](sources/nixos-26.05-release-notes.md) — initrd/systemd, system.nix, dbus-broker, container test backend, switch inhibitors, removals.
- [NixOS announcements](sources/nixos-announcements.md) — release timeline, governance, partnerships.

Concepts:

- [Nix/NixOS recent developments](concepts/nixos-recent-developments.md) — releases, technical changes, governance, user considerations.
- [sops-nix key sources](concepts/sops.md) — sops secret decryption key sources and the per-host configuration used by this repo's hosts (zurg fix: `services.openssh.generateHostKeys = true`).

## PHP php2shell exposure (CVE-2026-109618/109619)

Researched 2026-10-22, one day after the 2026-10-21 14:00 UTC security
release of PHP 8.2.35/8.3.36/8.4.27/8.5.12. Purpose: what the "php2shell" RCE
pair means for this repo, and which PHP it routines on.

### Orientation

- The pair: CVE-2026-109618 (OOM corruption → RCE) and CVE-2026-109619
  (stale global state → RCE), both pre-auth memory-safety bugs, CVSS 4.0 9.2;
  affected from PHP 5.4.0 through 8.5.11 (fixed versions are release-day
  points: 8.2.35/8.3.36/8.4.27/8.5.12). Facts, version table, exploitation
  timeline, IoCs and mitigations in
  [php2shell-advisory](sources/php2shell-advisory.md).
- Serving-mode risk (mod_php vs php-fpm/php-cgi/etc.) and the attack-path →
  config-lever mapping (memory_limit, session.upload_progress, fatal_error_backtraces)
  in [php-serving-modes-risk](concepts/php-serving-modes-risk.md).
- Repo exposure (nix-verified 2026-10-22): two PHP services only —
  **mrpotatohead runs nextcloud35 and woody runs zabbix74.web, both
  interpreters php 8.4.26 = the last vulnerable release** — because the root
  nixpkgs pin is `nixos-unstable` @ `55bfb4d7437bd4e09ab7cba58a43bd68eb310044`
  (locked 2026-10-14 05:35 UTC). nixpkgs-side fix = PR #576853 merged into
  master 2026-10-21 (commit `c53532a...`, bumps to 8.3.36/8.4.27/8.5.12 and
  marks php86 8.6.0RC3 insecure); php82 has no master module — 26.05 manual
  backport pending. Updating the flake inputs after the tips carry the fix
  then rebuilding mrpotatohead/woody restarts the affected php-fpm units.
- Log horizon for attack review: 2026-10-17 (pre-disclosure in-the-wild attempt),
  full IoC list in the advisory page.

### Open uncertainties

- php82 8.2.35 backport to the 26.05 nixpkgs branch — unresolved as of
  2026-10-22.
- watchTowr's "no patches for PHP 5/7" vs php.net's source-only backports
  for 7.4/8.0/8.1 — both documented per sense in the advisory page
  contradiction block.
- FrankenPHP nixpkgs update PR #577351 open; irrelevant while this repo runs
  nginx+php-fpm only.

## Coral USB TPU for ML log analysis (2026-11-04)

Purpose: assess whether a Google Coral USB Accelerator (Edge TPU) can serve as the ML accelerator for automatic log analysis, what its ceiling is, and how hard it is to realize — on this NixOS repo in particular. Research only — no Nix code modified. Bottom line: feasible, but a poor fit (Coral = quantized vision CNNs; logs = text/tabular/time-series models on the host CPU); on NixOS there is no libedgetpu/pycoral packaging (nixpkgs#188719 unresolved since 2022).

### Pages

- [capability & mismatch analysis](concepts/coral-tpu-for-log-analysis.md) — Edge TPU capability vs log-analysis ML shapes, feasibility verdict, effort estimate.
- [synthesis answers](syntheses/coral-tpu-log-analysis.md) — direct answers to the three questions (can it be used / ceiling / difficulty).

### Sources

- [USB Accelerator specs](sources/coral-usb-accelerator.md) — coral.ai datasheet + Mouser mirror: 4 TOPS INT8, 2 TOPS/W, USB 3.0 Type-C, ~8 MB SRAM.
- [Edge TPU compiler & model requirements](sources/coral-edge-tpu-compiler.md) — coral.ai compiler/models-intro/tflite-python: INT8 quantization, supported op list, graph partitioning at unsupported ops, PyCoral delegate inference.
- [Performance limits](sources/coral-performance-limits.md) — official benchmark latency table (MobileNet v2 2.6 ms, SSD 7.2 ms, etc.), thermals, real-world PyCoral timings.
- [ML for log analysis](sources/ml-for-log-analysis.md) — arXiv 2308.08736 (Wu et al. 2024), Khan et al. 2024 (PMC11330418), Red Hat Cordon 2025: parse → embed → SVM/LSTM/Transformer models on host CPU.
- [Coral on NixOS](sources/coral-on-nixos.md) — nixpkgs#188719 (unresolved), pycoral version-matching, ecosystem maintenance risk.

### Open uncertainties

- No published evidence found of log-analysis models (LSTM/MLP over template counts) actually running on Edge TPU.
- NixOS runtime integration path unresolved (nixpkgs#188719); coral apt repo/libedgetpu build status on modern kernels unverified for this repo.
- Long-term support of the original Coral software stack is uncertain (EDGE AI wiki notes a "Coral is back"/Coralboard direction at Google I/O 2026).

## Artifact-first updates (2026-11-13)

Question: *"Some of my hosts have trouble rebuilding due to memory
pressure. What can we do to alleviate this without compromising on the
independence?"* Decision in
[ADR-0018](../../docs/adr/0018-artifact-first-updates.md): woody
pre-builds pricklepants/jessie/slinky closures and serves a manifest;
those hosts substitute + switch and keep the untouched local
eval-and-build path as the failure fallback (ADR-0000 bar). Slinky's
kernel reaches the harmonia cache as a byproduct; fleet builders
advertise `big-parallel` + aarch64.

### Pages

- [synthesis](syntheses/artifact-first-updates.md) — diagnosis
  (pricklepants/jessie eval bill, four reasons slinky's kernel was never
  cacheable), the publisher/client split, fallback mechanics, and the
  watch-list (no auto-reboot in the artifact path, manifest carries no
  trust, woody disk guard).

## Unify-aspects dedupe migration (2026-11-04 → 2026-11-11)

Purpose: remove the copy-paste remaining above the ADR-0014 end state —
bootstrap split, vps-guest aspect, mesh-port collector, nebula lighthouse
flavor, xkb/basics fill-ins — under a strict zero-behavior-change rule
verified by per-host toplevel derivation-path equality. Decision recorded in
[ADR-0016](../../docs/adr/0016-unify-aspects-dedupe.md).

### Pages

- [synthesis](syntheses/unify-aspects.md) — commit map (c3aa130…c6a22db,
  net −740 lines), verification protocol, semantic-neutral delta ledger,
  preserved-drift list, deferred queue (user/credentials, flake.lib helpers).

### Conventions established

- Refactors are verified by `toplevel.drvPath` equality per host; every drv
  delta is explained to a single option and judged semantic-neutral before
  landing.
- Drift is preserved verbatim via explicit overrides, never silently unified
  by a dedupe commit.
- slinky (aarch64) used to be IFD-bound (oom-hardware `dtbs-filtered`) and
  was verified by targeted option evals only; since ADR-0019 (nixos-uconsole
  migration) it evaluates fully on x86_64 and is skipped by `just check`
  merely for the system mismatch.

## Conventions

- Claims in concept/synthesis pages cite the source pages inline.
- Source pages carry the external URLs.
- Version-sensitive claims are marked; code wins over prose.
