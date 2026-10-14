# WireGuard Peer CRUD Tool — Design

Date: 2026-10-14
Status: Draft (awaiting user review)

## Problem

WireGuard server config lives in `modules/wireguard.nix`, imported by the three
WG server hosts (`buzz`, `jessie`, `pricklepants`). Adding, changing, or removing
a peer today means hand-editing two places:

1. `modules/wireguard.nix` — the peer's `publicKey`, `allowedIPs`, and `name`.
2. `secrets/services/wireguard/secrets.yaml` — the peer's preshared key
   (`wireguard/peer/<name>`), via sops.

IP allocation across the tunnel (`10.66.66.0/24`, `fd42:42:42::/64`) is manual
and non-sequential, so collisions are easy. Creating a client also requires
hand-generating a keypair, assembling a `.conf`, and producing a QR code.

Goal: one script that owns the peer list and produces a working client bundle.

## Goals

- Single source of truth for the peer list, consumed by the Nix module.
- `add` generates a complete, working client: keypair, preshared key, tunnel
  IPs, client `.conf`, and a scannable QR code.
- List / inspect / update / delete peers without hand-editing sops or Nix.
- Never commit client private keys in cleartext.
- Deterministic, collision-free IP allocation.

## Non-Goals

- No web UI, no API, no server-side daemon.
- No live peer changes without a Nix rebuild (`wg` is reconfigured by
  `nixos-rebuild`). The tool edits files; the operator rebuilds.
- Not changing the WG transport, ports, or the Nebula reachability work
  (`networking.nat.extraCommands` in `modules/wireguard.nix` stays as-is).
- No revocation protocol beyond removing the peer entry on rebuild.

## Security Context

The repo is **public**. Threat model notes:

- WireGuard **public keys**, tunnel **IPs** (RFC1918/ULA), and the endpoint
  **FQDN** are public-by-design (public keys travel in cleartext during every
  handshake; the FQDN is already in DNS + Certificate Transparency logs). They
  are safe to commit.
- The repo already exposes host owners' names (`HOSTS.md`) and public VPS IPs
  (`modules/nebula.nix`), so peer names add no meaningful new identity leak.
  Peer names stay readable.
- The secrets that matter — server private key, preshared keys, client private
  keys — are encrypted with sops and never committed in cleartext.

Hardening in this design: the new client-config store gets a **dedicated sops
creation rule limited to admin age keys**, so the server hosts cannot decrypt
client private keys even though they can decrypt the peer preshared keys they
need.

## Architecture

Three stores, one script.

| Store | Path | Contents | Plaintext? |
|---|---|---|---|
| Peer list | `global/wireguard-peers.json` (new, committed) | server block (port, addresses, server public key) + per-peer name, public key, allowed IPs | yes |
| Preshared keys | `secrets/services/wireguard/secrets.yaml` (existing) | `wireguard/private`, `wireguard/public`, `wireguard/peer/<name>` | no (sops) |
| Client secrets | `secrets/services/wireguard/clients.yaml` (new) | `clients/<name>`: `private_key` (+ optional per-client `endpoint`/`dns`) | no (sops) |

`modules/wireguard.nix` reads the JSON at evaluation time via
`builtins.fromJSON (builtins.readFile ../global/wireguard-peers.json)` and
generates both `sops.secrets` declarations and the `peers` list. One data file
drives all three servers.

**Why plaintext JSON and not an encrypted peer file:** Nix evaluates the module
at build time and cannot read sops ciphertext, so peers that are declared
declaratively in Nix must be plaintext. Keeping them in sops would force a
deploy-time (imperative) `wg setconf`, losing declarative config. Given the JSON
holds only public-by-design data (see Security Context), plaintext is the right
trade.

## Data File Schema

`global/wireguard-peers.json`:

```json
{
  "server": {
    "listen_port": 55025,
    "address": ["10.66.66.1/24", "fd42:42:42::1/64"],
    "public_key": "<server public key, migrated from sops wireguard/public>"
  },
  "peers": [
    {
      "name": "test1",
      "public_key": "zsHRKnTjUwQZqOdO0OhkJ9qdztLPjFoS7fMbjnvW71w=",
      "allowed_ips": ["10.66.66.2/32", "fd42:42:42::2/128"]
    },
    {
      "name": "ks273fb",
      "public_key": "esB7TUn2MVaNDNuLrQOyEJ0ahNj1Fcv+j/ijypmA5yg=",
      "allowed_ips": ["10.66.66.4/32", "fd42:42:42::4/128", "192.168.178.0/24"]
    }
  ]
}
```

- `server.listen_port` and `server.address` are the single source of truth for
  the interface's port and IPs (today hardcoded in the module). Host-specific
  NAT settings (`networking.nat.externalInterface`, `ens6` vs `eth0`) stay in
  the host files, **not** in this JSON.
- `server.public_key` is the server's own public key (public-by-design). It is
  used by the script to render client configs so the renderer never needs sops
  for it. It is migrated from the existing `wireguard/public` sops entry, which
  is currently stored but referenced nowhere in the repo.
- Client tunnel subnets for allocation are derived from `server.address`
  (`10.66.66.0/24`, `fd42:42:42::/64`); the server address is excluded.
- `allowed_ips` may contain CIDRs **outside** the tunnel subnets — a peer that
  routes a LAN (e.g. `192.168.178.0/24` for `ks273fb`, the FRITZ LAN-LAN
  bridge). Allocation only ever assigns tunnel addresses; non-tunnel entries
  are carried through verbatim and never reallocated. (Server-side, the
  mark-based masquerade in `modules/wireguard.nix` makes these routed sources
  reach the mesh too.)
- `peers` order is preserved; the module maps it 1:1.

## Client `.conf` Template

```ini
[Interface]
PrivateKey = <client private key>
Address = 10.66.66.X/32, fd42:42:42::X/128
DNS = 10.0.0.1

[Peer]
PublicKey = <server.public_key, read from JSON>
PresharedKey = <preshared key, read from sops>
Endpoint = vpn.kauderwels.ch:55025
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```

- `Endpoint` host default `vpn.kauderwels.ch` (DNS round-robins across the three
  servers); the port is always `server.listen_port`, so it is never hardcoded
  twice. `--endpoint` accepts `host` or `host:port`; when no port is given,
  `server.listen_port` is appended. Overridable per client.
- `DNS` default `10.0.0.1` (the Nebula lighthouse). Overridable with `--dns`.
- `AllowedIPs` default `0.0.0.0/0, ::/0` (full tunnel). The `10.0.0.0/24` split
  to the mesh happens server-side; clients tunnel everything.

## CLI

Script: `functions/wireguard-peers.py` (Python 3 + `yaml`, mirrors
`functions/rotate-secrets.py` conventions). Run from repo root.

Common flags: `--age-key PATH` (or `SOPS_AGE_KEY_FILE` env; required for any
command that reads/writes sops), `--dry-run`.

| Command | Behaviour |
|---|---|
| `list` | Table: name, tunnel v4/v6, extra routed CIDRs, has-PSK, has-client-key. |
| `add <name> [--endpoint H[:P]] [--dns IP] [--routes CSV] [--tunnel-ip IP]` | Validate `name` and check for collisions. Generate client keypair (`wg genkey`/`wg pubkey`) and preshared key (`wg genpsk`); allocate lowest free v4+v6 tunnel addresses (or use `--tunnel-ip`, repeatable); append `--routes` CIDRs as extra allowed IPs. Write PSK to sops `wireguard/peer/<name>`; append peer to JSON; store `private_key` (+ any `endpoint`/`dns` overrides) in `clients.yaml`; print the client `.conf` + QR as advertised and a "rebuild servers" reminder. |
| `show <name>` | Re-render the client `.conf` (+ QR) from JSON `allowed_ips` + `server.public_key` + the stored `private_key` (`clients.yaml`) + the PSK (`secrets.yaml`). If no stored key exists (legacy peer), print the server-side `[Peer]` block with a clear banner that the client private key is not stored. |
| `export <name> --out FILE` | Same render as `show`, written to `FILE`. Errors if no stored client key exists (exporting a server-side block would mislead). |
| `update <name> [--rotate-psk] [--new-name N] [--allowed-ips CSV] [--routes CSV]` | `--rotate-psk`: new preshared key in sops. `--new-name`: rename in JSON, sops key, `clients.yaml`. `--allowed-ips`: replace the peer's allowed IPs entirely, validated to still contain ≥1 tunnel address. `--routes`: convenience to add/keep routed CIDRs. The `.conf` is re-rendered on demand, so nothing else needs rewriting. |
| `delete <name>` | Remove from JSON, delete sops `wireguard/peer/<name>`, delete the `clients.yaml` entry. Reminder: rebuild servers to drop the peer. |

**Validation.** `name` must match `^[A-Za-z0-9][A-Za-z0-9._-]*$` (it is used as a
sops path segment). `add` errors if the name already exists in the JSON **or** in
a sops `wireguard/peer/` key; `update --new-name` applies the same check.

QR codes render to the terminal via `qrencode -t ansiutf8` (nix-shell). `list`
does not require the age key. `show`/`export` of a stored client key require the
age key to decrypt **both** `clients.yaml` and `secrets.yaml` (the PSK). Commands
that write require it for the sops round-trip.

## sops Handling

Reuse the `rotate-secrets.py` approach, with the recipient source made explicit:

- Decrypt: `sops -d` with `SOPS_AGE_KEY_FILE` set from `--age-key`.
- **Existing** encrypted files (`secrets.yaml`): recipients are read from the
  encrypted file's own metadata (`sops.age[].recipient`) and re-encrypted with
  the **same** set, so updates never silently widen or narrow access.
- **New** `clients.yaml` (first write): it does not exist yet, so recipients come
  from the repo `.sops.yaml` rule below. Encrypt with
  `SOPS_CONFIG=<repo>/.sops.yaml` and `sops --filename-override
  secrets/services/wireguard/clients.yaml -e`, so the dedicated admin-only rule
  applies. **Do not** reuse `rotate-secrets.py`'s temp-`SOPS_CONFIG` path here:
  that path needs the recipient list baked in, which would duplicate (and risk
  drifting from) `.sops.yaml`. Subsequent `clients.yaml` writes read the embedded
  `sops.age[].recipient` set like any other existing file.
- Write atomically; then **round-trip**: decrypt again and assert the expected
  key/value is present. Abort on mismatch.
- Plaintext is written only to `0600` temp files (`NamedTemporaryFile`), never
  to the real path.

### `.sops.yaml` change

sops uses the **first matching** creation rule (top-to-bottom). The generic
`secrets/services/.+\.(yaml|json|env|ini)$` rule currently sits at line 119 and
would match `clients.yaml`; the new rule must be placed **before** it:

```yaml
  - path_regex: secrets/services/wireguard/clients\.yaml$
    key_groups:
      - age:
          - *admin_jerome
          - *bw_jerome
          - *bw_age_jerome
```

Result: client private keys are decryptable only by admin age keys, not by any
server host. (Side note, out of scope: the existing
`secrets/services/postgres/rclone.ini` rule at line 132 is dead code — it sits
after line 119, which already matches it. Leave it; not part of this change.)

## Allocation

- v4: lowest free host in `10.66.66.0/24`, starting at `.2`, excluding `.1`
  (server), `.0`/`.255`, and every address already covered by some peer's
  `allowed_ips`.
- v6: lowest free host in `fd42:42:42::/64`, starting at `::2`, excluding `::1`
  and covered addresses.
- **Collision test is CIDR containment, not equality.** A candidate is rejected
  if it lies inside *any* existing `allowed_ips` entry, computed with the stdlib
  `ipaddress` module (`ip in ip_network(entry)`). This matters because a peer may
  route a whole subnet (e.g. `ks273fb` → `192.168.178.0/24`) that happens to
  contain a would-be tunnel address, and because an existing `/32`/`/128` must
  block the exact address. If a routed CIDR covers the entire tunnel subnet,
  allocation fails with a clear "no free address" error rather than looping.
- Deterministic: same peer set ⇒ same allocation.
- `--tunnel-ip` pins specific tunnel address(es) instead of auto-allocation
  (repeatable); `--routes` appends extra non-tunnel CIDRs. Only tunnel addresses
  are subject to collision checks; routed CIDRs are carried verbatim.

## Module Refactor

`modules/wireguard.nix` becomes data-driven (behaviour unchanged):

```nix
{ config, pkgs, lib, ... }:
let
  wg = builtins.fromJSON (builtins.readFile ../global/wireguard-peers.json);
  peerSecret = p: "wireguard/peer/${p.name}";
  secretsFile = ../secrets/services/wireguard/secrets.yaml;
in
{
  # ... networking.nat block unchanged ...
  networking.firewall.allowedUDPPorts = [ wg.server.listen_port ];
  sops.secrets = {
    "wireguard/private" = { sopsFile = secretsFile; };
  } // builtins.listToAttrs (map (p: {
    name = peerSecret p;
    value = { sopsFile = secretsFile; };
  }) wg.peers);

  networking.wireguard.interfaces.wg0 = {
    listenPort = wg.server.listen_port;
    ips = wg.server.address;
    privateKeyFile = config.sops.secrets."wireguard/private".path;
    peers = map (p: {
      publicKey = p.public_key;
      allowedIPs = p.allowed_ips;
      presharedKeyFile = config.sops.secrets."wireguard/peer/${p.name}".path;
      name = p.name;
      persistentKeepalive = 25;
    }) wg.peers;
  };
}
```

Server-side SSOT for the port is now `server.listen_port`: it feeds both the
interface's `listenPort` and the firewall. `server.public_key` is used only by
the script (client rendering); the module does not need it.

## Migration of Existing Peers

Seed `global/wireguard-peers.json` from the current module:

- `test1` → `10.66.66.2/32`, `fd42:42:42::2/128`, pubkey `zsHR…`
- `ks273fb` → `10.66.66.4/32`, `fd42:42:42::4/128`, `192.168.178.0/24`,
  pubkey `esB7TUn2…`
- `giusi` → `10.66.66.10/32`, `fd42:42:42::10/128`, pubkey `2yqKN0Uv…`

Preshared keys already in sops are untouched. These legacy peers have **no
stored client key** in `clients.yaml`, so `show`/`export` yield the server-side
`[Peer]` block only; `list` marks them "no client key". Only new `add`s produce
full client bundles. The seed also carries `server.public_key`, migrated from
the existing `wireguard/public` sops entry (decrypt it once during migration).

Historical note: an earlier revision of the module had `ks273fb` carrying the
server's own public key; upstream commit `23ae2c8` fixed it to a proper client
key, and commit `4b980c2` added `192.168.178.0/24`. The seed above reflects the
post-update state.

## Verification / Testing

- **Self-test** (`python3 functions/wireguard-peers.py --selftest`): exercises
  pure logic on temp files with a stubbed key generator — allocation picks the
  lowest free v4+v6 and skips used/server addresses; a candidate inside a peer's
  routed subnet (e.g. `192.168.178.0/24`) is skipped (containment, not equality);
  a routed CIDR covering the whole tunnel errors; a duplicate name (JSON or sops)
  is rejected; `--routes` appends without disturbing tunnel addresses; `add`/
  `delete`/rename mutate the JSON as expected; round-trips JSON load/save. No
  sops, `wg`, or network.
- **sops round-trip** on every write (above), mirroring `rotate-secrets.py`.
- **Nix eval**: after migration, `nix eval` on `buzz`, `jessie`,
  `pricklepants` must show the same `peers` list as before the refactor.
- **Dry-run** prints the planned JSON/sops/client changes without writing.

## Risks / Open Points

- Any command that writes sops needs an admin age key with access to
  `secrets/services/wireguard/`. Documented in usage.
- `global/wireguard-peers.json` must be **git-added** before builds — flake
  evaluation ignores untracked files.
- `--endpoint` default host assumes the `vpn.kauderwels.ch` RR exists; operators
  with a different name pass `--endpoint`. Only the host is stored; the port
  always comes from `server.listen_port`.
- Trade (deliberate): `clients.yaml` stores only the non-derivable `private_key`
  (plus optional per-client `endpoint`/`dns`), **not** the rendered `.conf`.
  `allowed_ips`/tunnel IPs stay solely in the JSON (no second source of truth).
  Consequence: `show`/`export` must decrypt `secrets.yaml` for the PSK. This was
  chosen over a frozen config to avoid duplicating the key and the IP list.
- The `clients.yaml` admin-only rule depends on sops first-match ordering; the
  rule must stay above the generic services rule.
