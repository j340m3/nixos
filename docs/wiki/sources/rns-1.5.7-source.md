# Source: RNS 1.5.7 (PyPI sdist) and RNS 1.5.5 (installed)

Primary source notes for the Reticulum Network Stack code. Compiled 2026-10-19.

## Provenance

| Item | Value |
|---|---|
| Latest release checked | `rns` 1.5.7 |
| Artifact | <https://files.pythonhosted.org/packages/eb/62/ec929e1a614e0d9f5266f816d73a060eb6b0c89f6684e9ef0b7bedcac17d/rns-1.5.7.tar.gz> |
| SHA-256 | `2bb48232e0a10b59b2b21b60e76592362210cdabd343d7b97a3bf1aba22dd879` |
| Uploaded | 2026-10-05 11:54:54 UTC |
| PyPI metadata | <https://pypi.org/pypi/rns/1.5.7/json> |
| Extracted tree (ephemeral) | `/tmp/nix-shell.8cfcZx/opencode/rnsdocs/rns-1.5.7` |
| Installed on pricklepants | Nix store `qkv3j8gifl71ql1j834mfa01yylk29ca-python3.14-rns-1.5.5` (version 1.5.5) |
| Installed LXMF | Nix store `bxw9l66061k52sxq2g1dmgidc87fdlwy-python3.14-lxmf-1.2.0` |
| Repository | <https://github.com/markqvist/Reticulum> — README states this is a **public mirror**; development happens elsewhere |
| Manual source | <https://github.com/markqvist/Reticulum/tree/master/docs> (`docs/markdown/*.md`, `docs/source/*.rst`) |
| Rendered manual | <https://reticulum.network/manual/> |

Caveats:

- The mirror's `Changelog.md` stops at **1.5.5** (checked 2026-10-19). There is no upstream changelog entry for 1.5.6/1.5.7 in the mirror, so the 1.5.6/1.5.7 deltas below were established by diffing the installed 1.5.5 tree against the 1.5.7 sdist.
- Line numbers below refer to the 1.5.7 sdist unless stated otherwise.
- The project README carries a strong warning about LLM-generated "guides"/"implementations" ([README, PyPI description](https://pypi.org/pypi/rns/1.5.7/json)). Prefer source + official manual.

## Verified facts (code)

### Transport and instance settings

| Fact | Location |
|---|---|
| Transport disabled by default: `__transport_enabled = False` | `RNS/Reticulum.py:255` |
| `enable_transport` parsed: true sets `__transport_enabled = True` | `RNS/Reticulum.py:509-511` |
| `transport_enabled()` returns the flag | `RNS/Reticulum.py:2053-2064` |
| `discover_interfaces` defaults off; parsed at | `RNS/Reticulum.py:263-264`, `590-593` |
| `required_discovery_value` only set when `> 0`; otherwise `None` | `RNS/Reticulum.py:270`, `595-598` |
| `autoconnect_discovered_interfaces` only set when `> 0` | `RNS/Reticulum.py:265`, `630` |
| Discovery handler is started at instance start if enabled | `RNS/Reticulum.py:372-373` |
| `network_identity` loads/creates a key and registers it with Transport | `RNS/Reticulum.py:521-538` |
| `interface_discovery_sources` is a list of truncated identity hashes | `RNS/Reticulum.py:619-627` |
| `ifac_size` is parsed in **bits** (min 8) and divided by 8 | `RNS/Reticulum.py:152`, `886` |
| Default IFAC size 16 bytes | `RNS/Interfaces/Interface.py:96` |
| `ANNOUNCE_CAP = 2` (percent) | `RNS/Reticulum.py:114` |
| Announce-rate defaults: target 3600 s, penalty 0, grace 5 | `RNS/Interfaces/Interface.py:90-92` |
| `ingress_control` defaults on | `RNS/Interfaces/Interface.py:128` |

### Discovery: publishing (`discoverable`)

| Fact | Location |
|---|---|
| Default stamp value **16** (leading zero bits) | `RNS/Discovery.py:74` |
| `WORKBLOCK_EXPAND_ROUNDS = 20` | `RNS/Discovery.py:75` |
| Announcer identity = network identity if present, else instance identity | `RNS/Discovery.py:86-94` |
| Discovery destination aspect `rnstransport.discovery.interface` | `RNS/Discovery.py:49`, `93-94` |
| Announcer job runs every 60 s and announces interfaces that are due | `RNS/Discovery.py:73`, `107-132` |
| `announce_interval` is minutes; floor 5 min; default 360 min (6 h) | `RNS/Reticulum.py:997-1000` |
| `discovery_stamp_value`, `discovery_name`, `discovery_encrypt`, `reachable_on`, `publish_ifac`, location fields parsed | `RNS/Reticulum.py:1001-1017` |
| Discoverable on a non-gateway/internal/AP interface is forced to gateway (or AP for RNode) with a notice | `RNS/Reticulum.py:1019-1026` (identical in 1.5.5 at `1019-1022`) |
| `listen_on` is an alias for `listen_ip`; `remote` is an alias for `target_host` | `RNS/Reticulum.py:1121-1122` |
| Discovery payload includes interface type, `transport` bool, transport identity hash, implementation name/version, name, location, reachable_on, port, IFAC info | `RNS/Discovery.py:136-260` |
| `reachable_on` may be an executable whose stdout is used | `RNS/Discovery.py:188-205` |
| LXMF is required for discovery; missing LXMF logs critical and panics | `RNS/Discovery.py:78-84` |

### Discovery: learning (`discover_interfaces`)

| Fact | Location |
|---|---|
| Handler default `required_value` = 16 | `RNS/Discovery.py:264` |
| Handler drops announces from identities not in `interface_discovery_sources` | `RNS/Discovery.py:292-296` |
| Stamp validation via LXMF `LXStamper`; valid/invalid caches of 2048 entries | `RNS/Discovery.py:264-280`, `334` |
| Persisted discoveries live under `storage/discovery/interfaces` | `RNS/Discovery.py:510-512` |
| Stale thresholds: unknown 24 h, stale 3 d, remove 7 d | `RNS/Discovery.py:471-474` |
| Auto-connect types: `BackboneInterface` only | `RNS/Discovery.py:483` |
| Auto-connect requires implementation `RNS` and version >= 1.5.2 | `RNS/Discovery.py:486-487` |
| Auto-connected interfaces use gateway mode, gravity 0 | `RNS/Discovery.py:489-490`, `868` |
| 1.5.7 additionally requires the publisher's `transport` flag to be true before auto-connect | `RNS/Discovery.py:782-783` |
| 1.5.5 does **not** check the publisher transport flag | installed 1.5.5 `Discovery.py:782-790` |
| Auto-connection (and bootstrap detachment) is gated by `should_autoconnect_discovered_interfaces()`; with max 0 nothing auto-connects and no monitor starts | `RNS/Reticulum.py:2151`, `RNS/Discovery.py:795`, `877` |

### Interfaces

| Fact | Location |
|---|---|
| Mode constants: full 1, point-to-point 2, AP 3, roaming 4, boundary 5, gateway 6, internal 7 | `RNS/Interfaces/Interface.py:45-51` |
| Modes that discover paths for clients: AP, gateway, roaming, internal | `RNS/Interfaces/Interface.py:55` |
| `BackboneInterface` is Linux/Android-only | `RNS/Interfaces/BackboneInterface.py:131-132` |
| Listener options: `device` or `listen_ip`, `listen_port`/`port`, `prefer_ipv6` | `RNS/Interfaces/BackboneInterface.py:126-160` |
| Listener `supports_discovery = True` | `RNS/Interfaces/BackboneInterface.py:154` |
| Listener calls `server_socket.listen(1)` | `RNS/Interfaces/BackboneInterface.py:288` (also 1.5.5 `:287`) |
| Fast-flapping protection default on: threshold 20, grace 5 s, block 12 h | `RNS/Interfaces/BackboneInterface.py:48-51` |
| Client options: `target_host`, `target_port`, `connect_timeout`, `max_reconnect_tries`, `prefer_ipv6` | `RNS/Interfaces/BackboneInterface.py:861-869` |
| Client reconnect wait 5 s, unlimited tries by default | `RNS/Interfaces/BackboneInterface.py:846-847` |
| `BackboneClientInterface` has no `supports_discovery` | `RNS/Interfaces/BackboneInterface.py:843+` |

### Identity and transport persistence

| Fact | Location |
|---|---|
| Duplicate suppression uses `packet_hashlist` / `packet_hashlist_prev` | `RNS/Transport.py:172-173`, `1621`, `1668` |
| Destination/path table persists to `storage/destination_table` | `RNS/Transport.py:405-411`, `3860-3861` |
| Transport identity is saved to `storage/transport_identity` and reused | `RNS/Transport.py:320-330` |
| When transport is **disabled**, the transport identity is ephemeral unless `static_transport_identity` is set | `RNS/Transport.py:331-336` |
| 1.5.7: configuring a `discoverable` interface on a non-transport instance auto-enables `static_transport_identity` | `RNS/Reticulum.py:989-996` (absent in 1.5.5) |

### 1.5.5 → 1.5.7 delta (verified by diff)

Only four Python files differ (plus version metadata):

1. `RNS/Discovery.py`: auto-connect now rejects discovered interfaces whose publisher has `transport != True` (`:782-783`).
2. `RNS/Reticulum.py`: `discoverable` on a non-transport instance auto-enables `static_transport_identity` (`:989-996`).
3. `RNS/Interfaces/BackboneInterface.py`: adds `_dp_ec_reset()` on egress-control congestion disconnect (`:411-420`, `:445`).
4. `RNS/Utilities/rnodeconf.py`: unrelated RNode utility changes.

`RNS/Interfaces/Interface.py`, `RNS/Transport.py` and the rest are byte-identical between 1.5.5 and 1.5.7 (excluding `__pycache__`).
