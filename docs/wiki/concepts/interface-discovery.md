# Interface discovery

How RNS publishes and learns interface information over the network, what the `[reticulum]` discovery options actually control, and the version-specific behaviour that matters on RNS 1.5.x.

Sources: [S1](../sources/rns-1.5.7-source.md) (code), [S2](../sources/reticulum-manual.md) (manual), [S3](../sources/community-resources.md) (field reports).

## Two independent features

| Direction | Config | What it does |
|---|---|---|
| **Publish** | per-interface `discoverable = yes` | Periodically announces this interface's connection details under `rnstransport.discovery.interface`. |
| **Learn** | `[reticulum] discover_interfaces = yes` | Registers an announce handler, validates/records discoveries, optionally auto-connects. |

Neither requires the other. `discoverable` can be used without discovering, and `discover_interfaces` can be used without publishing ([S2](../sources/reticulum-manual.md), `interfaces.md` "Discoverable Interfaces"; [S1](../sources/rns-1.5.7-source.md), `RNS/Reticulum.py:372-373`, `989-1017`).

Both require **LXMF** to be importable. Missing LXMF makes the discovery code log a critical error and panic (`RNS/Discovery.py:78-84`, `264-275` in [S1](../sources/rns-1.5.7-source.md)). The host already has LXMF (needed by `lxmd`).

## Publishing (`discoverable = yes`)

Mechanics ([S1](../sources/rns-1.5.7-source.md) unless noted):

- An announcer thread checks every 60 s for discoverable interfaces whose `announce_interval` has elapsed, and sends a single announce on the discovery destination (`RNS/Discovery.py:73`, `107-132`).
- The announce identity is the configured **network identity** if present, otherwise the instance identity (`RNS/Discovery.py:86-94`). This is the `network_id` that discovering nodes record.
- Payload includes interface type, `transport` flag, transport identity hash, implementation name/version, name, location, `reachable_on`, port, and optionally IFAC name/key (`RNS/Discovery.py:136-260`).
- `reachable_on` is the address peers should connect to; for TCP/Backbone it is an IP or hostname **without a port** — the port comes from the interface itself. It may point to an executable that prints the address, for dynamic DNS/NAT/cloud (`RNS/Discovery.py:188-205`; [S2](../sources/reticulum-manual.md), `interfaces.md`).

Options and defaults ([S2](../sources/reticulum-manual.md), `interfaces.md`; code [S1](../sources/rns-1.5.7-source.md)):

| Option | Default | Notes |
|---|---|---|
| `discovery_name` | interface section name | Human-readable name shown to remote users. |
| `discovery_lxmf_address` | unset | Operator contact address. |
| `announce_interval` | 360 min (6 h) | Minutes; minimum 5. Manual suggests 12–22 h for stable infrastructure. |
| `discovery_stamp_value` | code **16** | Proof-of-work difficulty; docs say 14 (stale). Cached until info changes/restart. |
| `discovery_encrypt` | no | Encrypts payload; requires `network_identity`, otherwise announce aborted. |
| `publish_ifac` | no | Includes IFAC name/passphrase so peers can auto-configure. |
| `latitude`, `longitude`, `height` | unset | Optional location metadata. |

**Proof-of-work:** the stamp is a 256-bit hash with a number of leading zero bits equal to the stamp value; `stamp_valid` checks the hash is at most `2^(256-value)` (`LXMF/LXStamper.py:73-77`, cited in [S1](../sources/rns-1.5.7-source.md)). A value of 1 therefore accepts about half of all random stamps — effectively no spam filtering. The manual advises using as high a value as resources allow; the cost scales as 2^value and is paid once per announce generation, not by receivers (`interfaces.md`).

**Mode forcing:** setting `discoverable` on an interface whose mode is not `gateway`, `ap` or `internal` automatically switches it to gateway (or AP for RNode) and logs a notice (`RNS/Reticulum.py:1019-1026`; also in 1.5.5). This conflicts with deliberate `boundary` + `internal` designs; the community workaround is a dummy listener on localhost carrying only the discovery config, with `reachable_on` pointing at the real public address ([S3](../sources/community-resources.md); [S2](../sources/reticulum-manual.md) rendered HTML notes the behaviour).

## Learning (`discover_interfaces = yes`)

Mechanics ([S1](../sources/rns-1.5.7-source.md)):

- Starts `InterfaceDiscovery`, which registers an announce handler for the discovery destination (`RNS/Reticulum.py:372-373`).
- Validates the stamp; keeps valid/invalid caches of 2048 entries (`RNS/Discovery.py:264-280`, `334`).
- Records discoveries under `storage/discovery/interfaces` (`RNS/Discovery.py:510-512`), with states unknown (24 h), stale (3 d), removed (7 d) (`RNS/Discovery.py:471-474`).
- `interface_discovery_sources` (optional) restricts learning to specified announced identity hashes (`RNS/Reticulum.py:619-627`; `RNS/Discovery.py:292-296`).
- `rnstatus -d` / the discovery APIs list what was learned (`using.md` in [S2](../sources/reticulum-manual.md)).

### Auto-connect

`autoconnect_discovered_interfaces = N` (default 0) enables a monitor that connects up to N discovered interfaces (`RNS/Reticulum.py:630`, `2152`).

Eligibility ([S1](../sources/rns-1.5.7-source.md)):

- Type must be `BackboneInterface` (`RNS/Discovery.py:483`).
- Implementation must be `RNS` with version ≥ 1.5.2 (`RNS/Discovery.py:486-487`).
- **1.5.7:** the publisher must set `transport = true` in the announce (`RNS/Discovery.py:782-783`). **1.5.5 does not check this** (installed 1.5.5 `Discovery.py:782-790`). This is the main behavioural difference relevant to this host if it stays on 1.5.5.
- Auto-connected interfaces get gateway mode and gravity 0 (`RNS/Discovery.py:489-490`, `868`).
- `bootstrap_only` interfaces are detached once the auto-connected count reaches the configured max (`interfaces.md` in [S2](../sources/reticulum-manual.md)).

Auto-connect is designed for clients that want to grow connectivity organically, not for a public hub whose links should be deliberate. On a transport node, an auto-connected interface can create unintended topology and path churn.

## Recommended shape for a public transport node

- Publish the public listener: `discoverable = yes`, honest `discovery_name`/`reachable_on`, `announce_interval` 12–22 h, stamp ≥ 16 (higher if CPU allows) ([S2](../sources/reticulum-manual.md)).
- Learn without auto-connecting: `discover_interfaces = yes`, `autoconnect_discovered_interfaces = 0`, `required_discovery_value = 16`. This gives visibility (`rnstatus -d`) and lets the operator pick peers from the real directory of live nodes, while avoiding arbitrary attachments.
- Trade-off: `required_discovery_value = 16` hides publishers running pre-1.4.0 RNS, whose default stamp was 14 (the 1.4.0 changelog raised it to 16) ([S2](../sources/reticulum-manual.md), `Changelog.md:227`). That is acceptable for a new public node; lower the floor only if a specific legacy peer matters.
- Do **not** set `required_discovery_value = 1`; it defeats the stamp filter and is not a meaningful floor ([S1](../sources/rns-1.5.7-source.md), stamp semantics; current pricklepants config uses 1).
- Leave `interface_discovery_sources` unset unless deliberately restricting to a known network identity.

## Uncertainties

- Manual default 14 vs code default 16 for `discovery_stamp_value`: code says 16 and the 1.4.0 changelog records the change ([S1](../sources/rns-1.5.7-source.md); [S2](../sources/reticulum-manual.md), `Changelog.md:227`); docs are stale. `required_discovery_value` unset means the handler uses 16 (`RNS/Discovery.py:495-496`).
- 1.5.6/1.5.7 have no mirror changelog; the autoconnect transport check and the static-identity change were found by diffing 1.5.5 against 1.5.7 ([S1](../sources/rns-1.5.7-source.md)).
- IPv4/IPv6 listener binding: one forum report says a backbone listener binds a single family, another says `::` serves both. Code does not set `IPV6_V6ONLY`, so `::` is usually dual-stack on Linux, but test on the host ([S3](../sources/community-resources.md)).
