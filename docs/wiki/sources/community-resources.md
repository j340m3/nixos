# Source: Community resources and field reports

Compiled 2026-10-19. Secondary sources — useful for field experience, not authoritative over code/manual.

## Forum: rns.recipes

Community forum run by the rns.recipes directory. Not affiliated with the RNS maintainer. Threads are pseudonymous and unmoderated by the project.

### "BackboneInterface hub under heavy load"

- URL: <https://rns.recipes/forum/general/backboneinterface-hub-under-heavy-load>
- Category: General; started by `8c570775`, 2026-10-18 21:12 UTC.
- Reported setup: RNS **1.5.7**, public transport node on a **2 vCPU VPS**, two `BackboneInterface` listeners, **~500 connected clients**, 4 outgoing backbone peers, ~107 Hz inbound announces.
- Claims:
  - `BackboneInterface` uses `server_socket.listen(1)`. When its single job thread is busy, new connections beyond the first pending one are dropped; clients (Android, Windows) time out while established connections keep working. The reporter changed it locally to `listen(128)`, which "fixed this immediately", and asked for a configurable backlog.
  - Most job-thread time is spent on **announce signature verification**; `py-spy` samples during 5 s lag spikes were always in `validate_announce` → `Identity.validate` → ed25519 verify. Socket receive queues held 120–750 KB; application-visible lag up to ~16 s.
  - Suggested caching verification results for identical announces, noting that `packet_hash` masks the flags byte (context/ratchet bit), so a cache keyed only on `packet_hash` would be unsafe.
- No maintainer reply was visible when captured. Treat as a single field report; the backlog code is confirmed independently (see [RNS 1.5.7 source](rns-1.5.7-source.md), `listen(1)` at `BackboneInterface.py:288`).

### "Discoverable interfaces - working around limitations"

- URL: <https://rns.recipes/forum/build-guides/discoverable-interfaces-working-around-limitations>
- Category: Build Guides; author `jrrz.n`, 2026-10-02 (edited), replies through 2026-10-04.
- Claims:
  - In RNS **1.5.5**, only interfaces in `gateway`, `ap` or `internal` mode can be discoverable; setting `discoverable = yes` on another mode forces it back to gateway. This conflicts with using `boundary` on public listeners so that an `internal` (IFAC-protected) interface does not receive all global announces.
  - Workaround: create a **dummy** `BackboneInterface` listening on `localhost` that carries only the discovery configuration (`discoverable`, `discovery_name`, `reachable_on`, `announce_interval`, `discovery_stamp_value`, operator LXMF, location). Real public listeners stay in `boundary` mode with `recursive_prs = yes`; the internal listener stays `internal`.
  - Example values used: `announce_interval = 720` (12 h), `discovery_stamp_value = 24`, `gravity = 50` (public) / `100` (internal), `announce_rate_target = 10800`, `announce_rate_grace = 3`, `announce_rate_penalty = 43200`.
  - Separately, the author says Backbone listeners bind to either IPv4 or IPv6, so they use two listeners (one per family) plus the dummy discovery entry.
  - A reply (`Fox`) reports that `listen_on = ::` "does work in regards to responding both on IPv6 and IPv4", but that their gateway stopped appearing/updating on rmap.world and directory.rns.recipes; cause not established. This is an unverified field observation.
- This thread is the clearest public description of the discoverable-mode limitation and the dummy-interface workaround. Code confirms the mode forcing (see [RNS 1.5.7 source](rns-1.5.7-source.md)).

## Community wiki (Miraheze)

- "Transport node": <https://reticulum.miraheze.org/wiki/Transport_node>
  - Defines a transport node as an instance that routes across interfaces, propagates announces, maintains paths, serves path requests, and caches public keys.
  - Quotes the manual's "small number … strategically placed" guidance and "not every node should be a transport node".
  - Notes transport nodes ≠ LXMF propagation nodes.
- "Community node list": <https://reticulum.miraheze.org/wiki/Community_node_list>
  - Marked **Deprecated**: "Please use the built-in interface discovery mechanism or directory services."
  - Contains a historical list of public testnet/community `TCPClientInterface` entries (e.g. acehoss, Beleth, FireZen, g00n.cloud, interloper, mobilefabrik). Several hostnames in the current pricklepants config match this list, which suggests that config was seeded from pre-discovery community lists.
  - The page itself warns the nodes were never officially approved and users must judge trust.

## Directories

- <https://directory.rns.recipes/> — community interface directory (JS app). At capture on 2026-10-19 it displayed "No interfaces found" for both user-submitted and discovered tabs, so it was not usable as availability evidence.
- <https://rmap.world/> — mentioned by the official site as a bootstrapping directory; not audited here.

## Relation to the official docs

The community material adds operational detail not in the manual (backlog behavior under load, the discoverable-mode workaround, IPv4/IPv6 binding reports). It does not override the manual or code; where it conflicts, the code is treated as authoritative and the report is marked as field experience.
