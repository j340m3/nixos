# Source: pricklepants Reticulum configuration and NixOS module

Status: stale — captures the pre-2026-10-19 config (imperative root state copied into the repo). The repo file has since been rewritten: transport enabled, discoverable public gateway, five static peers, AutoInterface removed (see `syntheses/pricklepants-transport-node.md`).

Local project files read 2026-10-19. Not external documentation; included so the synthesis's claims about the current setup are traceable.

## Files

| File | Purpose |
|---|---|
| `modules/hosts/pricklepants/reticulum.conf` | Live RNS config installed as `/etc/reticulum/config` (via the host's `services.reticulum.configFile`). |
| `modules/hosts/pricklepants/default.nix` | Imports the Reticulum module and sets `configFile`. |
| `modules/reticulum.nix` | NixOS module: packages `rns` + `lxmf`, `rnsd`/`lxmd` systemd services, firewall rules. |

## Current `[reticulum]` values

From `reticulum.conf`:

- `enable_transport = False` (line 20)
- `share_instance = Yes` (line 32)
- `shared_instance_port = 37428`, `instance_control_port = 37429` (lines 41-42)
- `panic_on_interface_error = No` (line 51)
- `discover_interfaces = yes` (line 54)
- `required_discovery_value = 1` (line 55)
- `autoconnect_discovered_interfaces = 100` (line 56)
- `[logging] loglevel = 4` (line 71)

## Current `[interfaces]`

- `[[Default Interface]]`: `AutoInterface`, enabled (lines 90-94).
- 23 enabled `BackboneInterface` clients: Sydney, dismail, interloper, The Outpost, Beleth, Rocket Tech, SparkN0de, Tidudanka, quad4net, nisa-node, acehoss, RNS Testnet StoppedCold, RNS COMSEC-RD, R-Net, RNS TCP Node Germany 001/002, Quortal, mobilefabrik, g00n.cloud, RNS_Transport_US-East, rothbard ZA, rothbard ZA ygg, Sideband Hub (lines 96-233).
  - Most use `target_host` + `target_port`; Sideband Hub uses `remote =` + `target_port` + `transport_identity` (lines 228-233).
  - `rothbard_RNS_transport_ZA_ygg` uses a Yggdrasil IPv6 literal `200:73eb:...` (line 225).
- Commented `I2PInterface` block (lines 235-238).
- Disabled `RNodeInterface` with LoRa parameters (lines 241-312).

## NixOS module networking

From `modules/reticulum.nix`:

- `networking.firewall.allowedUDPPorts = [ 29716 42671 ];` (AutoInterface).
- `networking.firewall.extraCommands` accepts all multicast UDP via `iptables`/`ip6tables`.
- No inbound TCP port is opened.
- `rnsd` runs as `rnsd --config /var/lib/reticulum --service --verbose`, `Restart = always`, state under `/var/lib/reticulum`.
- `lxmd` runs after Reticulum, state under `/var/lib/lxmd`.
- The Python environment is `pkgs.python3.withPackages (ps: [ ps.rns ps.lxmf ])`.

## Observations relevant to the synthesis

- The host is configured for discovery learning but not for transport, and its discovery filter (`required_discovery_value = 1`) is effectively open.
- `autoconnect_discovered_interfaces = 100` combined with 23 static clients would permit a very large number of TCP connections.
- The peer list strongly resembles the deprecated community/testnet seed lists (see [community resources](community-resources.md)); several entries are bare IPs or well-known old hubs.
- `AutoInterface` cannot reach the public Reticulum network from a VPS segment; it only matters for link-local neighbours.
- The module would need a TCP listener firewall opening before a public `BackboneInterface` can serve peers.
