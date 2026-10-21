# Source: Official Reticulum manual and project pages

Compiled 2026-10-19. Primary documentation from the project author.

## Provenance

| Item | Value |
|---|---|
| Manual markdown (mirror) | <https://github.com/markqvist/Reticulum/tree/master/docs/markdown> |
| Manual RST source (mirror) | <https://github.com/markqvist/Reticulum/tree/master/docs/source> |
| Rendered manual | <https://reticulum.network/manual/> (HTML title observed as "Reticulum Network Stack 1.5.5 documentation") |
| Project site | <https://reticulum.network/> |
| Bootstrapping page | <https://reticulum.network/connect.html> |
| Fetched copies | `/tmp/nix-shell.8cfcZx/opencode/rnsdocs/*.md` (ephemeral) |
| Repository status | `github.com/markqvist/Reticulum` is a **public mirror**; development happens elsewhere (`README.md` / `MIRROR.md`) |

Chapters used:

- `networks.md` — Building Networks
- `gettingstartedfast.md` — Getting Started Fast
- `interfaces.md` — Configuring Interfaces
- `using.md` — Using Reticulum
- `Changelog.md` — mirror changelog (stops at 1.5.5)
- `connect.html` — Bootstrapping Connectivity (project site)

The README/PyPI description warns that many third-party Reticulum guides and implementations are LLM-generated, incorrect or license-violating, and directs users to the official manual and the "Community Implementations" list. This vault therefore prefers code + official manual and treats forum posts as secondary reports.

## Key claims

### Transport nodes

From `networks.md`, "Transport Nodes and Instances":

- An **Instance** is any system running RNS; a **Transport Node** is an instance explicitly configured to participate in network-wide transport: it forwards packets across hops, propagates announces, maintains path tables, serves path requests on behalf of other nodes, and caches destination public keys as a distributed keystore.
- **Not** every node should be a transport node. Reasons given: resource consumption (path tables, announces, forwarding), stability (frequent offline transport nodes cause stale path tables and poor convergence), and bandwidth (maintenance traffic on slow links).
- "In practice, a network typically has a relatively small number of Transport Nodes strategically placed to provide coverage and connectivity." End-user devices are instances connecting through nearby transport nodes.
- Services can be hosted from an instance without enabling transport; hosting a destination does not require being a transport node.
- Transport nodes are distinct from LXMF **propagation nodes**.

From the same chapter, "Trustless Networking":

- Reticulum targets open, trustless environments; end-to-end encryption/authentication means intermediate nodes cannot read/modify traffic.
- Redundant paths and multiple transport nodes mitigate malicious or broken nodes.
- Closed networks are supported via IFAC (restrict participation), Network Identities (verify discovered interfaces belong to trusted operators), and blackhole management (block identities).

### Public entrypoints

From `gettingstartedfast.md`, "Hosting Public Entrypoints":

- A public entrypoint needs a machine (physical or virtual) with a **public IP address** reachable from the Internet.
- `BackboneInterface` is the most efficient way to host a connectable entrypoint for many users; it is compatible with `TCPClientInterface`/`TCPServerInterface` and can handle thousands of connections on small systems.
- "It is also important to set your connectable interface to `gateway` mode, since this will greatly improve network convergence time and path resolution for anyone connecting to your entry-point."
- Official public gateway example: `mode = gateway`, `listen_on = 0.0.0.0`, `port = 4242`, and — "On publicly available interfaces, it is essential to configure sensible announce rate targets" — `announce_rate_target = 3600`, `announce_rate_penalty = 3600`, `announce_rate_grace = 6`.
- Private entrypoint variant: same listener plus `network_name` and `passphrase` (IFAC).

From `gettingstartedfast.md`, "Contributing to the Global Ret":

- Operators with a stable node and public IP are encouraged to become a public entrypoint and publish the interface as **discoverable**.

From `gettingstartedfast.md`, "Bootstrapping Connectivity" / "Build Personal Infrastructure":

- The global backbone is a voluntary, uncoordinated collection of public and private transport nodes.
- Recommended pattern: a personal always-on transport node with a `bootstrap_only` interface and interface discovery, so it discovers local peers and reduces dependence on distant static links.
- A `.rst`-only tip (present at `docs/source/gettingstartedfast.rst:165-166` but absent from the markdown conversion) says: "Don't rely on just a single connection to the distributed backbone for everyday use. It is much better to have several redundant connections configured, and enable the interface discovery options…"

From `https://reticulum.network/connect.html`:

- Reticulum is not a single network to join; bootstrapping is a local choice.
- A global distributed backbone of volunteer transport nodes exists; interface definitions are found at community directories `directory.rns.recipes` and `rmap.world`.
- Preferred growth model: temporary bootstrap links + discovery of more relevant/local infrastructure, then discarding bootstrap links ("organic growth").
- "Build Personal Infrastructure" recommends a local transport node rather than connecting every device directly to a public gateway.

### Discoverable interfaces (`interfaces.md`)

- Discovery is enabled per interface with `discoverable = yes`. RNS generates, signs, stamps and broadcasts announces on `rnstransport.discovery.interface`.
- "It is not *required* to enable Transport to publish interface discovery information, but for most use cases where you want others to connect to you, you will likely want `enable_transport` set to `yes`."
- `discovery_name` defaults to the interface section name; `discovery_lxmf_address` exposes operator contact.
- `announce_interval` is in minutes, default 360 (6 h), minimum 5; "For stable, long-running infrastructure, higher intervals (12 to 22 hours) are usually sufficient and reduce network load"; below 1 h expect throttling.
- `reachable_on` is the public IP/hostname (port is taken from the interface); it can be an executable that prints the address (dynamic DNS/NAT/cloud).
- `discovery_stamp_value` is proof-of-work difficulty (leading zero bits), cached and regenerated only when interface info changes or the instance restarts. The manual says the default is **14** (contradicted by code, see below) and: "If you have the computational resources, it is generally advisable to use as high a stamp value as possible."
- `discovery_encrypt = yes` encrypts the discovery payload; requires a `network_identity`; otherwise the announce is aborted.
- `publish_ifac = yes` includes IFAC name/passphrase in the announce.
- Optional `latitude`, `longitude`, `height`.
- The rendered manual (1.5.5 HTML) adds: if `discoverable` is set but the mode is not gateway/AP/internal, RNS automatically sets the appropriate mode and logs a notice.

### Interface options and modes (`interfaces.md`)

- Modes: `full`, `point_to_point`, `access_point`/`ap`, `roaming`, `boundary`, `gateway`/`gw`, `internal`.
- Gateway/AP/internal/roaming modes perform path discovery on behalf of clients; `boundary` is for links to substantially different network segments; `internal` is for private local segments.
- `announce_cap` defaults to 2 % of interface bandwidth; announces from nearby nodes are prioritised; excessive re-announcing is down-prioritised ("first-in-line" spamming backfires).
- `bootstrap_only` detaches an interface once the number of auto-connected interfaces reaches `autoconnect_discovered_interfaces`.
- `recursive_prs` enables recursive path discovery on an interface regardless of mode.
- `gravity` adjusts path affinity; defaults 0, positive increases affinity.
- `network_name` + `passphrase` enable IFAC; `ifac_size` is in bits (8–512), normally left at default.
- Backbone section: listener instances automatically block fast-flapping clients; defaults and options documented (`block_fast_flapping`, `fast_flapping_threshold`, `fast_flapping_grace`, `fast_flapping_block_time`).

### Using discovery / blackholes (`using.md`)

- `using.md` documents discovering interfaces (`rnstatus -d`), generating config entries, and blackhole management.
- Blackhole lists can be published/subscribed; `rnid` can be used to manage identities.
- The `rnsd --exampleconfig` comments say blackhole sourcing is "especially useful if you're hosting public entrypoints or gateways".

### Version/changelog

- `Changelog.md:212` — RNS 1.4.0 (2026-07-20).
- `Changelog.md:227` — "Increased default discovery stamp value to 16".
- Mirror changelog ends at 1.5.5; 1.5.6/1.5.7 have no mirror entry.

## Contradictions with code

- **Stamp default:** manual says 14; code default is 16 (`RNS/Discovery.py:74`), and the Changelog records the change to 16 in 1.4.0. The manual text is stale.
- **`discoverable` + mode:** the markdown chapter omits the mode-forcing note that the rendered 1.5.5 manual and the code contain. Code is authoritative: discoverable forces gateway (or AP for RNode) unless already gateway/AP/internal.
- **Bootstrap tip:** the redundancy tip exists only in the RST source, not the generated markdown. Both are official.

See [RNS 1.5.7 source](rns-1.5.7-source.md) for the code citations.
