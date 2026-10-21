# Transport nodes

What `enable_transport` does, when it is appropriate, and how a transport node fits into Reticulum topology.

Sources: [S1](../sources/rns-1.5.7-source.md) (code), [S2](../sources/reticulum-manual.md) (manual), [S3](../sources/community-resources.md) (field reports).

## What enabling transport does

A Reticulum **instance** can create destinations, send/receive packets and host services. A **transport node** additionally participates in network-wide transport: it forwards packets across interfaces, rebroadcasts announces, maintains path tables, answers path requests on behalf of other nodes, and caches destination public keys as a distributed keystore ([S2](../sources/reticulum-manual.md), `networks.md` "Transport Nodes and Instances").

In code, the flag gates the transport behaviour throughout `Transport.py` (path table, announce propagation, path requests, link/reverse routing); `Reticulum.transport_enabled()` is the common check ([S1](../sources/rns-1.5.7-source.md), `RNS/Reticulum.py:2053`, `RNS/Transport.py` uses at `:332`, `:1997`, `:3295`, `:3428`). Default is off (`RNS/Reticulum.py:255`).

Two consequences that are easy to miss:

1. **Transport identity persistence.** With transport enabled, the transport identity is created once, stored in `storage/transport_identity`, and reused ([S1](../sources/rns-1.5.7-source.md), `RNS/Transport.py:320-330`). With transport disabled, the transport identity is ephemeral unless `static_transport_identity = yes` is set (`RNS/Transport.py:331-336`). Discovery announces carry the transport identity hash, so a stable identity matters for discovery consistency.
2. **Announce-rate defaults activate.** When transport is enabled, any interface without explicit `announce_rate_target`/`penalty`/`grace` gets the defaults 3600 s / 0 / 5 (`RNS/Reticulum.py:968-971`; constants at `RNS/Interfaces/Interface.py:90-92`). This moderates how often received announces are re-broadcast per destination. On a public node the official example recommends explicit values anyway ([S2](../sources/reticulum-manual.md), `gettingstartedfast.md` "Hosting Public Entrypoints").

`enable_transport` does **not** require or imply `discover_interfaces`, and it is not required to publish a discoverable interface — though the manual says for most cases where you want others to connect, you will likely want transport on ([S2](../sources/reticulum-manual.md), `interfaces.md` "Discoverable Interfaces"). As of 1.5.7, a discoverable interface on a non-transport instance auto-enables `static_transport_identity` (`RNS/Reticulum.py:989-996`), so the advertised transport identity stays stable across restarts.

## When it is appropriate

The manual's criteria ([S2](../sources/reticulum-manual.md), `networks.md`):

- stationary;
- well-connected;
- kept running most of the time;
- enough CPU/memory/bandwidth for path tables, announce processing and forwarding.

The project site adds that a public entrypoint needs a reachable public IP and that `BackboneInterface` + gateway mode is the efficient way to serve many users ([S2](../sources/reticulum-manual.md), `gettingstartedfast.md` "Hosting Public Entrypoints").

A VPS with a public IP, always-on operation and generous bandwidth fits this profile. Home routers, laptops, phones and intermittent links generally do not; the manual explicitly says not every node should be a transport node, because resource use, stability and maintenance traffic all matter ([S2](../sources/reticulum-manual.md), `networks.md`).

## When not to enable it

All points are from the manual's criteria ([S2](../sources/reticulum-manual.md), `networks.md`):

- End-user devices: phones, laptops, sensors — run as instances and connect through a nearby transport node.
- Service hosts: a node can host destinations and LXMF propagation without being a transport node; connect it to a transport node instead.
- Low-bandwidth radio segments: transport nodes consume maintenance capacity on slow links (`networks.md`).
- Unstable or frequently-offline hosts: stale path tables hurt convergence.

## Topology guidance

- "A network typically has a relatively small number of Transport Nodes strategically placed to provide coverage and connectivity." Do not make every node a transport node ([S2](../sources/reticulum-manual.md), `networks.md`; corroborated by the community wiki [S3](../sources/community-resources.md)).
- Redundant paths and multiple transport nodes are the mitigation for malicious or failing nodes ([S2](../sources/reticulum-manual.md), `networks.md` "Trustless Networking").
- The official bootstrap tip is to configure **several redundant connections**, not a single backbone link (`docs/source/gettingstartedfast.rst:165-166`; absent from the generated markdown) ([S2](../sources/reticulum-manual.md)).
- Reticulum treats heterogeneity as normal: LoRa, Ethernet, Internet tunnels, I2P and radio links can coexist; no single medium or topology is required (`networks.md` "Heterogeneous Connectivity").
- **Loops:** no explicit loop-avoidance guidance is given in the manual. RNS suppresses duplicate packets/announces via its packet hash list ([S1](../sources/rns-1.5.7-source.md), `RNS/Transport.py:1621`, `1668`), so a physical loop is not catastrophic, but parallel paths cause path churn and redundant announce propagation. Prefer a simple, mostly-tree-shaped set of links; use interface `gravity` only if you need to bias path selection ([S2](../sources/reticulum-manual.md), `interfaces.md` "Common Interface Options").
- **Do not confuse transport nodes with LXMF propagation nodes.** Transport is multi-hop routing at the Reticulum layer; LXMF propagation stores messages asynchronously (`networks.md`; community wiki [S3](../sources/community-resources.md)).

## Capacity and cost

- Path table, known destinations and announce state consume RAM and disk; transport state persists between runs (`RNS/Transport.py:405-411` in [S1](../sources/rns-1.5.7-source.md)).
- Announce signature verification is the dominant CPU cost on a busy hub. A field report on a 2 vCPU VPS with ~500 clients and ~107 announce/s observed 5–16 s lag, attributed to signature checks in the single backbone job thread ([S3](../sources/community-resources.md)).
- `ANNOUNCE_CAP = 2` % limits announce bandwidth per interface; announces are prioritised by hop count and excessive announcers are moved back in the queue ([S1](../sources/rns-1.5.7-source.md), `RNS/Reticulum.py:114`; [S2](../sources/reticulum-manual.md), `interfaces.md`).

## Answers

**Q1 — should pricklepants enable transport?** Yes: it is stationary, always-on, public-IP, bandwidth-rich and CPU-adequate, and the intent is to contribute to the public backbone ([S2](../sources/reticulum-manual.md); see [synthesis](../syntheses/pricklepants-transport-node.md)).

**Q4 — how should it be connected?** A small number of redundant, reliable backbone peers; do not autoconnect to every discovered interface; prefer a deliberate set of geographically/operationally diverse links; keep the topology simple to limit path churn ([S2](../sources/reticulum-manual.md), `networks.md`, `gettingstartedfast.rst` tip).
