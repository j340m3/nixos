# Operating a public node

Practical and etiquette guidance for a public Reticulum entrypoint / transport node: firewalling, load, abuse handling, privacy controls and monitoring.

Sources: [S1](../sources/rns-1.5.7-source.md) (code), [S2](../sources/reticulum-manual.md) (manual), [S3](../sources/community-resources.md) (field reports), [S4](../sources/pricklepants-config.md) (current local config).

## Firewall and exposure

- A `BackboneInterface` listener binds a TCP port. Peers must be able to reach that port inbound: allow it in the host firewall (and any provider firewall) for the address family you bind ([S2](../sources/reticulum-manual.md), `gettingstartedfast.md` "Hosting Public Entrypoints"; listener bind code in [S1](../sources/rns-1.5.7-source.md)).
- The current NixOS module only opens **UDP 29716/42671** and multicast rules for `AutoInterface`; there is no inbound TCP allowance for a listener ([S4](../sources/pricklepants-config.md)). That must be added for a public entrypoint (the repo is not edited by this research).
- Remove `AutoInterface` (and its UDP/multicast firewall holes) on a datacenter VPS. It requires link-local IPv6 peers on the same L2 segment; a VPS has no meaningful Reticulum neighbours on that segment, and it adds needless exposure/traffic ([S1](../sources/rns-1.5.7-source.md), `AutoInterface.py` interface selection; [S2](../sources/reticulum-manual.md), `interfaces.md` AutoInterface section).
- There is **no TLS** on Backbone links. Reticulum provides end-to-end packet/link encryption and authentication; IFAC adds an interface authentication code, not confidentiality (`interfaces.md` common options; `networks.md` "Trustless Networking" in [S2](../sources/reticulum-manual.md)). Treat the public TCP port as an untrusted input path.
- `enable_remote_management` is off by default (`RNS/Reticulum.py:259`, `549-551`). Leave it off; if ever enabled, restrict `remote_management_allowed` to specific identities ([S1](../sources/rns-1.5.7-source.md), rnsd example config).

## Load and rate control

- `ANNOUNCE_CAP = 2` % per interface is the global default; announces are prioritised by hop count and repeat announcers are pushed back ([S1](../sources/rns-1.5.7-source.md), `RNS/Reticulum.py:114`; [S2](../sources/reticulum-manual.md), `interfaces.md`).
- With transport enabled, interfaces without explicit rate settings get target 3600 s, penalty 0, grace 5 (`RNS/Reticulum.py:968-971`; constants `Interface.py:90-92`) ([S1](../sources/rns-1.5.7-source.md)).
- Official public-listener recommendation: `announce_rate_target = 3600`, `announce_rate_penalty = 3600`, `announce_rate_grace = 6` — "essential" on public interfaces ([S2](../sources/reticulum-manual.md), "Hosting Public Entrypoints").
- Ingress control is on by default (`Interface.py:128`), and listener fast-flapping protection defaults to on (`block_fast_flapping`, threshold 20, grace 5 s, 12 h block) ([S1](../sources/rns-1.5.7-source.md)).
- Capacity: a 2 vCPU VPS was reported handling ~500 clients and ~107 announce/s, but with 5–16 s lag and connection drops due to `listen(1)` and single-threaded announce verification ([S3](../sources/community-resources.md)). For a busy public hub, plan for CPU headroom and watch this issue.
- `panic_on_interface_error = no` (default) keeps the daemon alive when an individual interface fails; appropriate for a server with no radio hardware ([S2](../sources/reticulum-manual.md), config example).

## Abuse handling

- **Blackhole sources.** You can subscribe to blackhole lists from trusted transport identities; the rnsd example comments call this "especially useful if you're hosting public entrypoints or gateways", and notes the sample source is only an example — better-maintained lists may exist ([S1](../sources/rns-1.5.7-source.md), `Utilities/rnsd.py:265-289`; [S2](../sources/reticulum-manual.md), `using.md` "Blackhole Management").
- **Publish your own list** (`publish_blackhole = yes`) only if you actually maintain it; otherwise subscribing is enough.
- Use `rnid`/`rnpath` to inspect and blackhole problematic identities; these are local policy decisions, not network-wide enforcement ([S2](../sources/reticulum-manual.md), `using.md`).
- The protocol deliberately provides no content filtering or prioritisation; transport nodes cannot inspect traffic, so abuse control is limited to identity-level blocking and rate limiting ([S2](../sources/reticulum-manual.md), `networks.md` "Trustless Networking").
- Log noise from flapping clients is expected; fast-flapping blocking exists to contain it (`interfaces.md`; changelog 1.3.9 in [S2](../sources/reticulum-manual.md)).

## Open vs closed networks

- **Open public entrypoint:** no IFAC passphrase. Anyone may connect; discovery announces are public. This is the intended public-backbone role ([S2](../sources/reticulum-manual.md), "Hosting Public Entrypoints" and "Discoverable Interfaces").
- **Private/community entrypoint:** add `network_name` + `passphrase` (IFAC); optionally `publish_ifac = yes` if you want discoverable peers to receive the credentials automatically ([S2](../sources/reticulum-manual.md), `interfaces.md`).
- **Network identity:** identifies a set of nodes as one operator/network; discovery announces are then signed by it, and discovering nodes can pin it via `interface_discovery_sources`. Use `discovery_encrypt` only with a network identity (otherwise announces abort) ([S1](../sources/rns-1.5.7-source.md), `RNS/Reticulum.py:521-538`, `619-627`; `Discovery.py:86-94`; [S2](../sources/reticulum-manual.md), `networks.md` "Trustless Networking").
- **Probes:** `respond_to_probes = yes` is optional; it exposes a probe destination derived from the transport identity and prints it at startup, useful for connectivity testing ([S1](../sources/rns-1.5.7-source.md), `rnsd.py:255-265`).

## Operator etiquette

Derived from the manual's guidance ([S2](../sources/reticulum-manual.md)):

- Announce at a sensible rate; "announce spamming" is counterproductive (announces are down-prioritised) and wasteful (`interfaces.md`).
- On discovery-published interfaces, use a realistic `discovery_name`, `discovery_lxmf_address` and location; announce interval 12–22 h is enough for stable infrastructure (`interfaces.md`).
- Use as high a discovery stamp value as the host can afford; it is a spam cost barrier, not a status symbol (`interfaces.md`).
- Don't autoconnect to everything you discover on a public hub; pick peers deliberately (`interfaces.md` `bootstrap_only`/autoconnect docs; [S3](../sources/community-resources.md)).
- Keep the node stable and updated — transport nodes that flap hurt convergence (`networks.md`).
- Don't run a transport node on a link where its maintenance traffic harms the local medium (`networks.md`).

## Monitoring and hygiene

- `rnstatus -a`, `rnstatus -d` (discovered interfaces), `rnpath`, `rnprobe`, `rnid`, `journalctl -u rnsd` ([S2](../sources/reticulum-manual.md), `using.md`; [S1](../sources/rns-1.5.7-source.md), utilities list).
- Keep `loglevel = 4` normally; lower to 3 if a busy hub produces excessive notices (config example in [S1](../sources/rns-1.5.7-source.md)).
- Track upstream: installed Nix package is **1.5.5**; latest release is **1.5.7** (2026-10-05). 1.5.7 contains an egress-control reset fix for Backbone disconnects and the autoconnect transport check; neither is in 1.5.5 ([S1](../sources/rns-1.5.7-source.md), delta section). The `listen(1)` backlog is present in both.
- No version of the documented setup requires opening anything beyond the chosen TCP listener port (plus ICMP/SSH for management). Avoid exposing `rnsd`'s shared-instance ports (37428/37429) to the Internet; they are local IPC sockets ([S2](../sources/reticulum-manual.md), config example).

## Answers

**Q3 — VPS caveats:** public TCP reachability, firewall change, no TLS, CPU cost of announce verification, single-threaded listener backlog, IPv4/IPv6 binding choice, and removal of the useless AutoInterface.

**Q5 — etiquette:** announce-rate limits, discovery interval/stamp discipline, blackhole lists for abuse, IFAC only for closed networks, no remote management by default, keep the node stable and updated.
