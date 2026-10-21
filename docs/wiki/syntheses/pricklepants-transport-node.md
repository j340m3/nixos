# Synthesis: pricklepants as a public transport node

Concrete recommendation for the Ionos VPS `pricklepants`, based on [transport nodes](../concepts/transport-nodes.md), [interface discovery](../concepts/interface-discovery.md), [backbone interface](../concepts/backbone-interface.md) and [public node operations](../concepts/public-node-operations.md).

**Verdict:** enable transport and publish a discoverable `BackboneInterface` gateway. The host matches every manual criterion: stationary, public IP, always-on, bandwidth-rich. Also fix the discovery thresholds (current values make the node auto-attach to arbitrary interfaces) and prune the 23 static peers.

## Changes to `[reticulum]`

Current (`modules/hosts/pricklepants/reticulum.conf`): `enable_transport = False`, `discover_interfaces = yes`, `required_discovery_value = 1`, `autoconnect_discovered_interfaces = 100` ([S4](../sources/pricklepants-config.md)).

Recommended:

```ini
[reticulum]
  # This host is exactly the profile the manual describes for a transport node.
  enable_transport = yes
  share_instance = yes

  # Learn what is out there, but never auto-attach on a public hub.
  discover_interfaces = yes
  required_discovery_value = 16
  autoconnect_discovered_interfaces = 0

  # Optional but useful for a public entrypoint:
  respond_to_probes = yes
  # network_identity = /var/lib/reticulum/storage/identity/network
  # blackhole_sources = <trusted transport identity hash>
  # publish_blackhole = no

[logging]
  loglevel = 4
```

Why each change:

| Setting | Current | Why change |
|---|---|---|
| `enable_transport` | no | The node is stationary, public and always-on; transport lets it forward packets, propagate announces, serve paths and cache keys ([S2](../sources/reticulum-manual.md), `networks.md`; [S1](../sources/rns-1.5.7-source.md), `RNS/Reticulum.py:509-511`). |
| `required_discovery_value` | 1 | 1 leading-zero bit accepts ~half of random stamps — effectively no spam filter. Code default is 16; the docs' "14" is stale ([S1](../sources/rns-1.5.7-source.md), `Discovery.py:74`; stamp math `LXStamper.py:73-77`). |
| `autoconnect_discovered_interfaces` | 100 | 100 arbitrary auto-connections plus 23 static peers is excessive and creates unintended topology. 0 is the documented default; use `rnstatus -d` to inspect and add peers deliberately ([S1](../sources/rns-1.5.7-source.md), `RNS/Reticulum.py:630`, `Discovery.py:483-490`; [S2](../sources/reticulum-manual.md), `interfaces.md`). |
| `respond_to_probes` | unset (no) | Optional; makes `rnprobe` connectivity tests possible for others ([S1](../sources/rns-1.5.7-source.md), `rnsd.py:255-265`). |
| `network_identity` | unset | Optional. Set it if you operate multiple nodes or want clients to pin your network; otherwise leave unset ([S1](../sources/rns-1.5.7-source.md), `RNS/Reticulum.py:521-538`; [S2](../sources/reticulum-manual.md), `networks.md`). |
| `blackhole_sources` | unset | Optional; useful for public entrypoints, but only subscribe to a list you trust ([S1](../sources/rns-1.5.7-source.md), `rnsd.py:265-289`). |

Notes:

- Enabling transport activates default announce-rate moderation (3600 s target) on interfaces that don't set their own (`RNS/Reticulum.py:968-971`; [S1](../sources/rns-1.5.7-source.md)). The public listener below sets explicit values anyway.
- Do **not** set `static_transport_identity`; it only applies when transport is off. With transport on, the transport identity is persistent automatically (`RNS/Transport.py:320-336`).

## Add a public listener

Add one listener to `[interfaces]` (and open the TCP port in the firewall):

```ini
[[Public Backbone]]
  type = BackboneInterface
  enabled = yes

  listen_ip = 0.0.0.0
  port = 4242

  mode = gateway
  discoverable = yes
  discovery_name = pricklepants
  reachable_on = <public hostname or IPv4>   # no port here

  announce_interval = 720          # 12 h
  discovery_stamp_value = 20       # >= 16; generated once and cached

  announce_rate_target = 3600
  announce_rate_penalty = 3600
  announce_rate_grace = 6
```

Rationale:

- Listener option names: RNS 1.5.7 reads `listen_ip` and `listen_port`; `listen_on` is copied to `listen_ip` and `port` overrides `listen_port` before construction (`BackboneInterface.py:136-139`, `RNS/Reticulum.py:1119-1122`).
- `gateway` mode is what the manual requires for a public entrypoint; discovery would force it anyway, but setting it avoids a notice ([S2](../sources/reticulum-manual.md), "Hosting Public Entrypoints"; [S1](../sources/rns-1.5.7-source.md), `RNS/Reticulum.py:1019-1026`).
- `reachable_on` is the public address peers should use; the port comes from the interface ([S2](../sources/reticulum-manual.md), `interfaces.md`).
- 12 h announcement interval is inside the manual's recommended 12–22 h band for stable infrastructure (default is 6 h, minimum 5 min) ([S2](../sources/reticulum-manual.md), `interfaces.md`).
- Stamp 20 is above the receiver default of 16 and costs ~2^20 hashes, generated only on change/restart; raise to 24 if desired (forum example uses 24), but note clients that set a *higher* `required_discovery_value` would reject lower stamps ([S2](../sources/reticulum-manual.md); [S1](../sources/rns-1.5.7-source.md)).
- `announce_rate_*` values are the official public-gateway example, called "essential" for public interfaces ([S2](../sources/reticulum-manual.md)).

IPv6: the code does not set `IPV6_V6ONLY`, so `listen_on = ::` is usually dual-stack on Linux, but community reports conflict. Start with IPv4 and test `::` separately; don't bind `0.0.0.0` and `[::]` to the same port simultaneously ([S3](../sources/community-resources.md)).

## Prune the static peers

`reticulum.conf` currently enables ~23 outbound `BackboneInterface` clients plus `AutoInterface` ([S4](../sources/pricklepants-config.md)). Problems:

- Many entries match the **deprecated** community/testnet seed lists; several are IP literals or long-dead hubs ([S3](../sources/community-resources.md), Community node list marked deprecated).
- 23 links multiply announce propagation work and reconnect/log noise; the manual recommends a few redundant connections, not a maximal list (`docs/source/gettingstartedfast.rst:165-166`; `interfaces.md` announce-cap behaviour in [S2](../sources/reticulum-manual.md)).
- AutoInterface has no useful neighbours on a VPS L2 segment and causes extra firewall exposure ([S1](../sources/rns-1.5.7-source.md), `AutoInterface.py` requires link-local IPv6).

Recommended:

1. Remove `[[Default Interface]]` (AutoInterface) and its UDP/multicast firewall allowances.
2. Keep **3–5** static peers, chosen by actual reachability and latency:
   - keep `Sideband Hub` (`sideband.connect.reticulum.network:7822`) — it appears in the official discovery example output and already carries a `transport_identity` ([S2](../sources/reticulum-manual.md), `using.md` discovery examples);
   - keep the Yggdrasil-addressed `rothbard_RNS_transport_ZA_ygg` only if `yggdrasil` is up and the peer answers — it provides path diversity via a different overlay;
   - keep 2–3 geographically sensible hubs that respond (e.g. one of the Sydney/dismail/interloper/Beleth/Outpost group), and delete the rest.
3. Re-verify each retained host with `rnstatus`/`rnpath`; delete unreachable entries instead of leaving them to retry forever.
4. Leave the disabled RNode and commented I2P block out of the final config unless you plan to use them; they add noise.

Do **not** enable `bootstrap_only` on the VPS: it only interacts with autoconnect. With `autoconnect_discovered_interfaces = 0` nothing is auto-connected, the monitor never starts, and bootstrap interfaces are never detached ([S1](../sources/rns-1.5.7-source.md), `RNS/Reticulum.py:2151`, `Discovery.py:795`; [S2](../sources/reticulum-manual.md), `interfaces.md`).

## Firewall / NixOS module

The module currently allows only UDP 29716/42671 + multicast for AutoInterface ([S4](../sources/pricklepants-config.md)). For this design:

- add inbound **TCP 4242** (or the chosen port) for the listener;
- remove the AutoInterface UDP/multicast allowances if the interface is removed;
- keep SSH/management access as-is.

This is a config change for the operator; this vault does not edit the Nix repo.

## Verification checklist

1. Restart `rnsd`; `journalctl -u rnsd` should show the listener, no "auto-configured to gateway" notice (mode already gateway), and no bind errors.
2. `rnstatus -a`: listener up and 3–5 peers online. Remove peers that stay offline.
3. First discovery announce fires within ~60 s of startup (`last_discovery_announce = 0`, announcer job interval 60 s) ([S1](../sources/rns-1.5.7-source.md), `Discovery.py:107-132`, `Interface.py:120`).
4. From another node with `discover_interfaces = yes` and `required_discovery_value = 16`, run `rnstatus -d` and look for `pricklepants`. Propagation may take a little time; a restart re-announces.
5. From a client connected to the listener, verify multi-hop path resolution (`rnpath <destination>`) and, if enabled, `rnprobe`.
6. Watch CPU and `journalctl` under load. If client counts reach the hundreds, expect the `listen(1)` backlog and single-thread announce verification to matter ([S3](../sources/community-resources.md); [S1](../sources/rns-1.5.7-source.md), `BackboneInterface.py:288`).

## Version flags

- Installed: RNS **1.5.5** (Nix store). Latest: **1.5.7** (2026-10-05).
- 1.5.7 changes relevant here: autoconnect only considers transport-publishing nodes (irrelevant with autoconnect 0), discoverable on a non-transport instance keeps a stable transport identity (irrelevant with transport on), egress-control reset fix on Backbone disconnect (relevant), and the `listen(1)` backlog is still present ([S1](../sources/rns-1.5.7-source.md), delta section).
- The manual's stamp default (14) is stale vs code (16); rely on code and the 1.4.0 changelog entry ([S1](../sources/rns-1.5.7-source.md); [S2](../sources/reticulum-manual.md), `Changelog.md:227`).
- Directory availability and peer liveness were not verifiable: `directory.rns.recipes` returned no entries at capture time ([S3](../sources/community-resources.md)).
