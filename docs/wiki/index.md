# Wiki index — knowledge vault

Two research threads live here; each topic below is self-contained with its own
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

## Conventions

- Claims in concept/synthesis pages cite the source pages inline.
- Source pages carry the external URLs.
- Version-sensitive claims are marked; code wins over prose.
