# Backbone interface

`BackboneInterface` is the efficient TCP interface type used for public entrypoints and high-connection-count hubs on Linux. This page records listener/client mechanics, relevant options, and known operational caveats for RNS 1.5.x.

Sources: [S1](../sources/rns-1.5.7-source.md) (code), [S2](../sources/reticulum-manual.md) (manual), [S3](../sources/community-resources.md) (field reports).

## Why use it

- The manual calls `BackboneInterface` "the most efficient and performant way to host a connectable entry-point supporting many users"; it is compatible with `TCPClientInterface`/`TCPServerInterface` but much faster and lighter, and can handle thousands of connections on small systems ([S2](../sources/reticulum-manual.md), `gettingstartedfast.md` "Hosting Public Entrypoints"; `interfaces.md` Backbone section).
- It is Linux/Android-only (`RNS/Interfaces/BackboneInterface.py:131-132` in [S1](../sources/rns-1.5.7-source.md)).
- Listener mode uses an epoll loop and a single job thread; each accepted socket is wrapped in a spawned client interface (`BackboneInterface.py` around `:270-300`).

## Listener vs client

The same `type = BackboneInterface` is used for both; the class is chosen by presence of `target_host` ([S1](../sources/rns-1.5.7-source.md), `RNS/Reticulum.py:1124-1127`):

- **Listener** (server): needs `listen_ip`/`listen_on` (or `device`) and `port`/`listen_port`.
- **Client**: needs `target_host` (alias `remote`) and `target_port`.

Aliases applied before construction ([S1](../sources/rns-1.5.7-source.md), `RNS/Reticulum.py:1119-1122`):

- `port` → `listen_port` and `target_port`
- `remote` → `target_host`
- `listen_on` → `listen_ip`

Listener options include `device`, `listen_ip`, `bind_port`/`port`, `prefer_ipv6`; client options include `target_host`, `target_port`, `connect_timeout`, `max_reconnect_tries`, `prefer_ipv6` (`BackboneInterface.py:126-160`, `861-869`). Clients reconnect every 5 s with unlimited tries by default (`BackboneInterface.py:846-847`).

## Public listener configuration

The official public entrypoint example ([S2](../sources/reticulum-manual.md), `gettingstartedfast.md`):

```ini
[[Public Gateway]]
  type = BackboneInterface
  enabled = yes
  mode = gateway
  listen_on = 0.0.0.0
  port = 4242

  # "essential" on publicly available interfaces
  announce_rate_target = 3600
  announce_rate_penalty = 3600
  announce_rate_grace = 6
```

To also publish it:

```ini
  discoverable = yes
  discovery_name = <name>
  reachable_on = <public hostname or IP>   # no port
  announce_interval = 720                  # minutes; 12 h
  discovery_stamp_value = 20               # >= 16; raise for spam resistance
```

Mode notes:

- `gateway` is the correct mode for a public entrypoint; it improves convergence and path resolution for clients ([S2](../sources/reticulum-manual.md), "Hosting Public Entrypoints").
- Setting `discoverable` on a non-gateway/AP/internal interface forces gateway mode (or AP for RNode) ([S1](../sources/rns-1.5.7-source.md), `RNS/Reticulum.py:1019-1026`).
- If the node also has an `internal` IFAC segment, keep the public listener in `boundary` mode with `recursive_prs = yes`, and use the dummy-discovery-listener workaround to avoid the forced gateway mode ([S3](../sources/community-resources.md)).

## Fast-flapping protection

Listener instances track clients that connect/dump/disconnect quickly and block them ([S2](../sources/reticulum-manual.md), `interfaces.md` Backbone section; [S1](../sources/rns-1.5.7-source.md)):

- `block_fast_flapping = yes` (default)
- `fast_flapping_threshold = 20`
- `fast_flapping_grace = 5` seconds
- `fast_flapping_block_time` = 12 h default

This exists because rate limits trigger immediately, and spammers reconnect repeatedly to bypass; the block reduces log noise and interface churn (`interfaces.md`).

## Known caveat: listen backlog of 1

The listener calls `server_socket.listen(1)` in 1.5.7 (and 1.5.5) — confirmed in code (`BackboneInterface.py:288` in [S1](../sources/rns-1.5.7-source.md)). With a single pending-connection queue slot, bursts of new connections while the job thread is busy can be dropped or time out. A field report on a 2 vCPU VPS with ~500 clients says changing it to `listen(128)` fixed connection failures immediately ([S3](../sources/community-resources.md)).

- Not configurable in current releases; requires an upstream patch or a local package override.
- The same report attributes lag spikes to announce signature verification in the single job thread, not only to the backlog.
- Treat the backlog as a real scaling limit for a busy public hub until upstream changes it; factor it into expectations for hundreds of simultaneous clients.

## IPv4/IPv6 binding

- `listen_on = 0.0.0.0` binds IPv4 only; `listen_on = ::` binds IPv6 (usually dual-stack on Linux because the code does not set `IPV6_V6ONLY`).
- One community report says backbone listeners bind a single family and uses two listeners; another reports `::` serving both IPv4 and IPv6, but also suspects `::` caused discovery listings to stop updating ([S3](../sources/community-resources.md)).
- No official guidance resolves this. Recommendation: start with IPv4 (`0.0.0.0`), verify with an external client, and only add IPv6 after testing `reachable_on`/discovery behaviour.

## Security properties

- Backbone is plain TCP; there is no TLS. Reticulum encrypts/authenticates at the packet/link layer end-to-end, and IFAC adds an HMAC-style interface authentication code, not transport encryption (`interfaces.md` "Common Interface Options"; manual's trustless-networking section in [S2](../sources/reticulum-manual.md)).
- Any client can connect unless the listener uses IFAC (`network_name` + `passphrase`) ([S2](../sources/reticulum-manual.md), "Hosting Public Entrypoints" private variant).
- Ingress control is enabled by default (`RNS/Interfaces/Interface.py:128`), and fast-flapping blocking is on; blackhole lists can be sourced/published for persistent abuse ([S2](../sources/reticulum-manual.md), `using.md`).

## Answer

**Q6 (interface mechanics):** use a `BackboneInterface` listener with `mode = gateway`, a TCP port opened in the firewall, `reachable_on` set to the public name/IP, announce-rate limits, and discovery publishing; keep the backlog caveat in mind for high client counts.
