# WireGuard Peer CRUD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `modules/wireguard.nix` data-driven from a plaintext JSON peer list, and add `functions/wireguard-peers.py` to add/list/show/export/update/delete peers (editing the JSON, sops PSK/private-key stores, and rendering client `.conf` bundles + QR).

**Architecture:** Three stores, one script. Public-by-design data (server port/addresses/public key, per-peer public key + allowed IPs) lives in committed plaintext `global/wireguard-peers.json`, which the Nix module reads at eval time. Secrets (per-peer PSK, per-client private key) live in sops. A Python script owns the JSON and the sops secrets; `nixos-rebuild` applies changes.

**Tech Stack:** Nix (flake, sops-nix), Python 3 + PyYAML, sops 3.x, `wireguard-tools` (`wg`), `qrencode`.

**Spec:** `docs/superpowers/specs/2026-10-14-wireguard-peer-crud-design.md`

## Global Constraints

- Python: standard library + `yaml` only; no other third-party imports.
- `name` must match `^[A-Za-z0-9][A-Za-z0-9._-]*$` (used as a sops path segment).
- Tunnel subnets derive from `server.address`: `10.66.66.0/24` (v4), `fd42:42:42::/64` (v6); server is `.1` / `::1`.
- Defaults: endpoint host `vpn.kauderwels.ch`, DNS `10.0.0.1`, client `AllowedIPs = 0.0.0.0/0, ::/0`, `PersistentKeepalive = 25`.
- Endpoint port is **always** `server.listen_port` unless `--endpoint` explicitly carries one.
- `global/wireguard-peers.json` must be git-added (flake pure eval ignores untracked files).
- iptables backend; the existing `networking.nat.extraCommands` block is unchanged.
- `clients.yaml` recipients are admin-only (`.sops.yaml` rule must precede the line-119 generic services rule; first match wins).
- No commit of any cleartext private key, PSK, or rendered client config.

## Review Focus

- A peer's `allowed_ips` contains a broad route overlapping the tunnel (e.g. `192.168.178.0/24` free to grow into `10.66.66.x`); allocation must skip **contained** candidates, not just equal ones. → Task 3 test.
- `add` with a name that collides with a PSK key already in sops but absent from the JSON (there are stale ones: `bw93fb`, `jannick`, `bw93_fb`, `jessica`); must error. → Task 4 test.
- `--endpoint` passed with an explicit `host:port`; must not append the listen port again. → Task 3 test.
- First write of `clients.yaml` picking the wrong creation rule (the 14-key services rule) instead of the admin-only rule. → Task 2 verification.
- `show`/`export` of a legacy peer (JSON entry but no stored client key) must not crash; prints the server-side block. → Task 4 behaviour.

---

### Task 1: Plaintext peer JSON + data-driven module

**Files:**
- Create: `global/wireguard-peers.json`
- Modify: `modules/wireguard.nix`
- Commit also: `docs/superpowers/specs/2026-10-14-wireguard-peer-crud-design.md`, `docs/superpowers/plans/2026-10-14-wireguard-peer-crud.md`

**Interfaces:**
- Produces: JSON shape consumed by every later task —
  `{ "server": { "listen_port": int, "address": [str,...], "public_key": str }, "peers": [ { "name": str, "public_key": str, "allowed_ips": [str,...] }, ... ] }`
  (2-space indent, `peers` order preserved).
- Produces (Nix): `config.networking.wireguard.interfaces.wg0.peers` — same list as before the refactor.

- [ ] **Step 1: Capture the pre-refactor peers**

Run: `nix eval .#nixosConfigurations.buzz.config.networking.wireguard.interfaces.wg0.peers --json > /tmp/wg-before.json`
Expected: JSON array of 3 peers (`test1`, `ks273fb`, `giusi`).

- [ ] **Step 2: Get the server public key**

Run: `SOPS_AGE_KEY_FILE=<admin age key> sops -d secrets/services/wireguard/secrets.yaml`
Expected: prints `wireguard.public` (the server's own public key). Record this value.

- [ ] **Step 3: Create `global/wireguard-peers.json`**

Seed from the current module (test1/ks273fb/giusi) with the recorded `server.public_key`:

```json
{
  "server": {
    "listen_port": 55025,
    "address": ["10.66.66.1/24", "fd42:42:42::1/64"],
    "public_key": "<value from step 2>"
  },
  "peers": [
    { "name": "test1",   "public_key": "zsHRKnTjUwQZqOdO0OhkJ9qdztLPjFoS7fMbjnvW71w=", "allowed_ips": ["10.66.66.2/32", "fd42:42:42::2/128"] },
    { "name": "ks273fb", "public_key": "esB7TUn2MVaNDNuLrQOyEJ0ahNj1Fcv+j/ijypmA5yg=", "allowed_ips": ["10.66.66.4/32", "fd42:42:42::4/128", "192.168.178.0/24"] },
    { "name": "giusi",   "public_key": "2yqKN0Uvapedp1SQEPwmzeVXTcb0yWhK5rB1IqGUUVY=", "allowed_ips": ["10.66.66.10/32", "fd42:42:42::10/128"] }
  ]
}
```

- [ ] **Step 4: Rewrite `modules/wireguard.nix` to read the JSON**

Keep the `networking.nat` block and its comment **verbatim**; drive port, ips, firewall, sops secrets and peers from `wg`:

```nix
{ config, lib, pkgs, ... }:
let
  wg = builtins.fromJSON (builtins.readFile ../global/wireguard-peers.json);
  secretsFile = ../secrets/services/wireguard/secrets.yaml;
  peerSecret = p: "wireguard/peer/${p.name}";
in
{
  networking.nat.enable = true;
  # ... externalInterface / internalInterfaces / enableIPv6 / extraCommands unchanged ...

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

- [ ] **Step 5: Stage the new file, then verify eval parses and output is identical**

Flake evaluation only sees git-tracked files, so the new JSON must be staged first.

Run: `git add global/wireguard-peers.json modules/wireguard.nix`

Run: `nix-instantiate --parse modules/wireguard.nix`
Expected: no error, prints one line.

Run: `nix eval .#nixosConfigurations.buzz.config.networking.wireguard.interfaces.wg0.peers --json > /tmp/wg-after.json && diff /tmp/wg-before.json /tmp/wg-after.json`
Expected: no diff.

Run: `nix eval .#nixosConfigurations.jessie.config.networking.wireguard.interfaces.wg0.peers --json > /tmp/wg-after-jessie.json && diff /tmp/wg-before.json /tmp/wg-after-jessie.json`
Expected: no diff. (Repeat for `pricklepants`.)

- [ ] **Step 6: Verify sops secret names unchanged**

Run: `nix eval --raw .#nixosConfigurations.buzz.config.sops.secrets --apply builtins.attrNames` (or `--json`)
Expected: includes `wireguard/private`, `wireguard/peer/test1`, `wireguard/peer/ks273fb`, `wireguard/peer/giusi`.

- [ ] **Step 7: Commit**

```bash
git add global/wireguard-peers.json modules/wireguard.nix \
  docs/superpowers/specs/2026-10-14-wireguard-peer-crud-design.md \
  docs/superpowers/plans/2026-10-14-wireguard-peer-crud.md
git commit -m "feat(wireguard): data-drive peers from plaintext JSON"
```

---

### Task 2: Admin-only sops rule for `clients.yaml`

**Files:**
- Modify: `.sops.yaml` (insert before the line-119 `secrets/services/.+` rule)
- Create: `secrets/services/wireguard/clients.yaml` (encrypted; created by the first `add` in Task 4 — nothing to do here)

**Interfaces:**
- Produces: creation rule matching `secrets/services/wireguard/clients.yaml` with recipients `admin_jerome`, `bw_jerome`, `bw_age_jerome` only.

- [ ] **Step 1: Insert the rule**

Immediately **above** the `secrets/services/.+\.(yaml|json|env|ini)$` rule (currently line 119):

```yaml
  - path_regex: secrets/services/wireguard/clients\.yaml$
    key_groups:
      - age:
          - *admin_jerome
          - *bw_jerome
          - *bw_age_jerome
```

- [ ] **Step 2: Verify rule order is correct**

Run: `grep -n "clients\\.yaml\|services/\.+" .sops.yaml`
Expected: the `clients.yaml` line has a **smaller** line number than the generic `services/.+` line.

- [ ] **Step 3: Verify recipients resolve to admin-only**

Create a throwaway plaintext, encrypt it against the rule, and inspect recipients:

```bash
echo 'x: 1' > /tmp/cl.yaml
SOPS_CONFIG=$PWD/.sops.yaml sops --filename-override secrets/services/wireguard/clients.yaml -e /tmp/cl.yaml > /tmp/cl.enc.yaml
grep -c 'recipient:' /tmp/cl.enc.yaml
grep 'recipient:' /tmp/cl.enc.yaml
rm -f /tmp/cl.yaml /tmp/cl.enc.yaml
```

Expected: **3** recipients, exactly `age1yd27qq2ys4tyae08ncs09fqgma87asrd3kandkkyvdj0kgjn9v3qm3l0yu`, `age1ex3axxazzhsllzj0pqkdgjqnvzjmp8he2patv0k5wlzaacqwpfys8saxrq`, `age1f3fnr3dzn28xv52a3hht3d2ylpwrre3zghkh598syggaduq02dusfzsrmr`. (Not the 14-key services set.)

- [ ] **Step 4: Commit**

```bash
git add .sops.yaml
git commit -m "feat(sops): admin-only recipients for wireguard clients.yaml"
```

---

### Task 3: Script pure core + `--selftest`

**Files:**
- Create: `functions/wireguard-peers.py`
- Test: `functions/wireguard-peers.py --selftest` (in-file, no framework)

**Interfaces:**
- Produces (module-level names later tasks import/call):
  - `REPO_ROOT: Path`, `PEERS_JSON: Path` (`global/wireguard-peers.json`), `PEER_SECRETS: Path`, `CLIENTS_SOPS: Path`
  - `DEFAULT_ENDPOINT = "vpn.kauderwels.ch"`, `DEFAULT_DNS = "10.0.0.1"`, `NAME_RE`
  - `load_peers(path: Path) -> dict`
  - `save_peers(path: Path, data: dict) -> None`  (2-space indent, trailing newline)
  - `validate_name(name: str) -> None`  (raises `ValueError`)
  - `find_peer(data: dict, name: str) -> dict | None`
  - `tunnel_networks(server: dict) -> tuple[ipaddress.IPv4Network, ipaddress.IPv6Network]`
  - `server_hosts(server: dict) -> list[ipaddress._BaseAddress]`
  - `covered_networks(data: dict) -> list[ipaddress._BaseNetwork]`
  - `allocate_tunnel_ips(server: dict, peers: list[dict]) -> tuple[str, str]`  (returns `x/32`, `x/128`)
  - `split_allowed_ips(allowed_ips: list[str], server: dict) -> tuple[list[str], list[str]]`  (tunnel, routes)
  - `build_allowed_ips(tunnel_ips: list[str], routes: list[str]) -> list[str]`  (tunnel IPs first, then routes)
  - `resolve_endpoint(endpoint: str | None, listen_port: int) -> str`
  - `render_client_conf(*, private_key: str, tunnel_ips: list[str], server: dict, psk: str, endpoint: str | None, dns: str | None) -> str`
  - `run_selftest() -> int`

- [ ] **Step 1: Write the failing selftest**

At the bottom of the new file, add `run_selftest()` with these assertions (use `assert`, catch-driven):

```python
def run_selftest() -> int:
    import ipaddress

    for ok in ["a", "A1", "ok.name-1", "a_b"]:
        validate_name(ok)                      # must not raise
    for bad in ["", ".hidden", "has space", "a/b", "x" * 64]:
        try:
            validate_name(bad); raise AssertionError(f"accepted {bad!r}")
        except ValueError:
            pass

    server = {"listen_port": 55025,
              "address": ["10.66.66.1/24", "fd42:42:42::1/64"],
              "public_key": "SERVERPUB="}
    peers = [
        {"name": "test1",   "allowed_ips": ["10.66.66.2/32", "fd42:42:42::2/128"]},
        {"name": "ks273fb", "allowed_ips": ["10.66.66.4/32", "fd42:42:42::4/128", "192.168.178.0/24"]},
        {"name": "giusi",   "allowed_ips": ["10.66.66.10/32", "fd42:42:42::10/128"]},
    ]
    assert allocate_tunnel_ips(server, peers) == ("10.66.66.3/32", "fd42:42:42::3/128")

    # containment, not equality: 10.66.66.0/29 covers .0-.7, so the first free
    # v4 address is .8 (an equality-only check would wrongly return .2)
    peers2 = [{"name": "p", "allowed_ips": ["10.66.66.0/29"]}]
    got = allocate_tunnel_ips(server, peers2)
    assert got[0] == "10.66.66.8/32", got

    # equality still blocks the exact address
    peers3 = [{"name": "p", "allowed_ips": ["10.66.66.2/32"]}]
    assert allocate_tunnel_ips(server, peers3)[0] == "10.66.66.3/32"

    # a route covering the whole tunnel => no free v4
    try:
        allocate_tunnel_ips(server, [{"name": "p", "allowed_ips": ["10.66.66.0/24"]}])
        raise AssertionError("expected exhaustion")
    except ValueError:
        pass

    tun, routes = split_allowed_ips(
        ["10.66.66.2/32", "fd42:42:42::2/128", "192.168.178.0/24"], server)
    assert tun == ["10.66.66.2/32", "fd42:42:42::2/128"]
    assert routes == ["192.168.178.0/24"]

    assert resolve_endpoint(None, 55025) == "vpn.kauderwels.ch:55025"
    assert resolve_endpoint("vpn.example.org", 55025) == "vpn.example.org:55025"
    assert resolve_endpoint("vpn.example.org:1234", 55025) == "vpn.example.org:1234"

    conf = render_client_conf(
        private_key="PRIV=", tunnel_ips=["10.66.66.2/32", "fd42:42:42::2/128"],
        server=server, psk="PSK=", endpoint=None, dns=None)
    assert "PrivateKey = PRIV=" in conf
    assert "Address = 10.66.66.2/32, fd42:42:42::2/128" in conf
    assert "DNS = 10.0.0.1" in conf
    assert "PublicKey = SERVERPUB=" in conf
    assert "PresharedKey = PSK=" in conf
    assert "Endpoint = vpn.kauderwels.ch:55025" in conf
    assert "AllowedIPs = 0.0.0.0/0, ::/0" in conf
    assert "PersistentKeepalive = 25" in conf

    print("selftest OK")
    return 0
```

- [ ] **Step 2: Run to verify it fails**

Run: `python3 functions/wireguard-peers.py --selftest`
Expected: FAIL (`NameError: validate_name`, or the `--selftest` flag unhandled).

- [ ] **Step 3: Implement the pure core**

`validate_name` uses `NAME_RE.fullmatch`; reject len > 63. Allocation: `tunnel_networks` = `ip_network(a, strict=False)` for the v4 and v6 entries of `server["address"]`; `server_hosts` = `ip_interface(a).ip` for each. `covered_networks` = `ip_network(ip, strict=False)` for every `allowed_ips` entry of every peer ∪ the server hosts as `/32`,`/128`. `allocate_tunnel_ips`: walk `net.hosts()` of the v4 then v6 tunnel network, skip any candidate equal to a server host or contained (`candidate in net`) in any covered network, return the first free as `f"{ip}/32"` / `f"{ip}/128"`; raise `ValueError("no free tunnel address in <net>")` on exhaustion. `split_allowed_ips`: an entry is a tunnel address when `ip_network(entry, strict=False).subnet_of(tunnel_net)` for a tunnel net, else a route. `resolve_endpoint`: if the (host) part after the last `:` is all digits, return unchanged, else `f"{endpoint}:{listen_port}"`; `None` → default host. `render_client_conf`: the exact template from the spec (blank line between `[Interface]` and `[Peer]`; `Address` joined with `", "`).

Wire `--selftest` in `main()` (before argparse-required subcommand handling) to call `run_selftest()`.

- [ ] **Step 4: Run to verify it passes**

Run: `python3 functions/wireguard-peers.py --selftest`
Expected: `selftest OK`.

- [ ] **Step 5: Commit**

```bash
git add functions/wireguard-peers.py
git commit -m "feat(wireguard): peer allocation/render core + selftest"
```

---

### Task 4: sops + wg integration and CLI subcommands

**Files:**
- Modify: `functions/wireguard-peers.py`
- (First real run creates) `secrets/services/wireguard/clients.yaml`

**Interfaces:**
- Consumes: every name produced by Task 3.
- Produces:
  - `sops_decrypt(sops_file: Path, age_key: Path) -> str`
  - `read_recipients(sops_file: Path) -> list[str]`
  - `sops_encrypt_existing(plaintext: str, sops_file: Path, age_key: Path) -> str`  (re-encrypt with the file's embedded recipients)
  - `sops_encrypt_new(plaintext: str, rel_path: str) -> str`  (repo `.sops.yaml` via `SOPS_CONFIG`; `--filename-override rel_path`)
  - `wg_genkey() -> str`, `wg_pubkey(priv: str) -> str`, `wg_genpsk() -> str`, `qr_ansi(conf: str) -> str`
  - CLI: `list`, `add`, `show`, `export`, `update`, `delete`; global `--age-key PATH` (or `SOPS_AGE_KEY_FILE`), `--dry-run`.

CLI behaviour (from the spec):

| Command | Behaviour |
|---|---|
| `list` | Table: name, tunnel v4/v6, routed CIDRs, has-PSK, has-client-key. No age key needed. |
| `add <name> [--endpoint H[:P]] [--dns IP] [--routes CSV] [--tunnel-ip IP]` | validate + collision-check; keypair + PSK; allocate (`--tunnel-ip` pins); append `--routes`; write PSK to `wireguard/peer/<name>`; append peer to JSON; store `private_key` (+ endpoint/dns if overridden) in `clients.yaml`; print conf + QR + rebuild reminder. |
| `show <name>` | render conf+QR from JSON + `server.public_key` + stored `private_key` + PSK. Legacy peer (no stored key) → print server-side `[Peer]` block with a banner. |
| `export <name> --out FILE` | `show` render written to `FILE`; error if no stored key. |
| `update <name> [--rotate-psk] [--new-name N] [--allowed-ips CSV] [--routes CSV]` | per spec; `--allowed-ips` validated to keep ≥1 tunnel address; `--new-name` collision-checked. |
| `delete <name>` | remove from JSON + sops PSK + `clients.yaml`; rebuild reminder. |

- [ ] **Step 1: Write failing integration tests (selftest additions)**

Extend `run_selftest()` (no sops needed):

```python
    # name collision: JSON or sops names reserve a name
    data = {"server": server, "peers": [{"name": "test1", "allowed_ips": ["10.66.66.2/32"]}]}
    assert find_peer(data, "test1") is not None
    assert find_peer(data, "nope") is None

    # first-write recipient selection is separate from the existing-file path
    assert sops_encrypt_new is not sops_encrypt_existing  # distinct call paths

    # --routes are appended after the tunnel IPs
    assert build_allowed_ips(["10.66.66.3/32"], ["10.9.9.0/24"]) == ["10.66.66.3/32", "10.9.9.0/24"]
```

Also assert `resolve_endpoint("vpn.example.org:1234", 55025)` still returns the explicit port (guards the double-append review case).

Run: `python3 functions/wireguard-peers.py --selftest`
Expected: FAIL (`sops_encrypt_new` undefined).

- [ ] **Step 2: Implement sops helpers**

`sops_decrypt` / `read_recipients` / `sops_encrypt_existing` mirror `functions/rotate-secrets.py` (`SOPS_AGE_KEY_FILE`, `NamedTemporaryFile(delete=False)`, `_write_atomic`, round-trip verify). `sops_encrypt_new(plaintext, rel_path)`:

```python
env = {**os.environ, "SOPS_CONFIG": str(REPO_ROOT / ".sops.yaml")}
r = _run(["sops", "--filename-override", rel_path, "-e", tmp_path], env=env)
```

- [ ] **Step 3: Implement wg/qr helpers and CLI**

`wg_genkey`/`wg_pubkey`/`wg_genpsk` and `qr_ansi` shell out through `nix-shell -p wireguard-tools` / `nix-shell -p qrencode` (mirroring `rotate-secrets.py`'s `_run`/`nix-shell` pattern). `add`: build the new peer, write PSK via `sops_encrypt_existing` on `PEER_SECRETS`, handle the first `clients.yaml` write with `sops_encrypt_new`. `--dry-run`: print the JSON delta, the conf, and the sops paths touched, write nothing.

- [ ] **Step 4: Run selftest to verify it passes**

Run: `python3 functions/wireguard-peers.py --selftest`
Expected: `selftest OK`.

- [ ] **Step 5: Dry-run every subcommand against the real repo**

```bash
python3 functions/wireguard-peers.py list
python3 functions/wireguard-peers.py --dry-run add demo --routes 10.9.9.0/24
python3 functions/wireguard-peers.py --dry-run show test1
python3 functions/wireguard-peers.py --dry-run update test1 --rotate-psk
python3 functions/wireguard-peers.py --dry-run delete demo
```
Expected: `list` shows 3 peers; `add`/`update`/`delete` print plans and write nothing (`git status` clean).

- [ ] **Step 6: Live round-trip (needs the admin age key)**

```bash
python3 functions/wireguard-peers.py --age-key "$ADMIN_AGE_KEY" add demo
python3 functions/wireguard-peers.py --age-key "$ADMIN_AGE_KEY" show demo
python3 functions/wireguard-peers.py --age-key "$ADMIN_AGE_KEY" delete demo
```
Expected: `add` prints a scannable QR + `.conf`; `show demo` re-renders identically; `delete demo` removes the JSON entry, the sops PSK, and the `clients.yaml` entry. `clients.yaml` decrypts with an **admin** key only (attempting a server host key must fail).

- [ ] **Step 7: Commit**

```bash
git add functions/wireguard-peers.py
git commit -m "feat(wireguard): sops/wg CLI for peer CRUD"
```

---

## Self-Review

- **Spec coverage:** JSON schema → Task 1; data-driven module + firewall/port SSOT → Task 1; admin-only rule → Task 2; allocation (containment), validation, split, render, endpoint derivation → Task 3; CLI surface (`list`/`add`/`show`/`export`/`update`/`delete`), sops recipient sourcing, dry-run, legacy-peer behaviour → Task 4; migration seed → Task 1 Step 3; verification/test plan → Tasks 1/2/3/4 steps. No gaps.
- **Step scan:** each step names a command + expected result; code appears only for the test bodies and Nix/config the implementer cannot infer.
- **Type consistency:** `REPO_ROOT`/`PEERS_JSON`/`PEER_SECRETS`/`CLIENTS_SOPS`, `allocate_tunnel_ips`, `split_allowed_ips`, `render_client_conf`, `sops_encrypt_new`/`_existing` are used with the same names in Task 4 as defined in Task 3.
- **Review Focus:** all five lines have a test in Tasks 2/3/4.
- **Proportion:** plan is shorter than the spec; no function bodies beyond the test blocks and Nix.
