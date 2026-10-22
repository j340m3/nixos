# Wiki index — knowledge vault

Four research threads live here; each topic below is self-contained with its own
orientation and page lists.

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

## Nix/NixOS recent developments (2024–2026)

Purpose: orientation on recent Nix/NixOS changes worth considering for a user.

### Pages

Sources:

- [NixOS 26.05 release notes](sources/nixos-26.05-release-notes.md) — initrd/systemd, system.nix, dbus-broker, container test backend, switch inhibitors, removals.
- [NixOS announcements](sources/nixos-announcements.md) — release timeline, governance, partnerships.

Concepts:

- [Nix/NixOS recent developments](concepts/nixos-recent-developments.md) — releases, technical changes, governance, user considerations.

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

## Conventions

- Claims in concept/synthesis pages cite the source pages inline.
- Source pages carry the external URLs.
- Version-sensitive claims are marked; code wins over prose.
