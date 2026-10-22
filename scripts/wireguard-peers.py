#!/usr/bin/env python3
"""WireGuard peer CRUD — validation, allocation, rendering, and CLI.

The pure core (validation, allocation, rendering) has no sops/wg dependency.
The CLI layer shells out to sops (directly) and to wg/qrencode (via nix-shell),
mirroring scripts/rotate-secrets.py.

Usage:
  wireguard-peers.py list
  wireguard-peers.py --age-key KEY add <name> [--endpoint H[:P]] [--dns IP]
                     [--routes CSV] [--tunnel-ip IP]
  wireguard-peers.py --age-key KEY show <name>
  wireguard-peers.py --age-key KEY export <name> --out FILE
  wireguard-peers.py --age-key KEY update <name> [--rotate-psk] [--new-name N]
                     [--allowed-ips CSV] [--routes CSV]
  wireguard-peers.py --age-key KEY delete <name>
  wireguard-peers.py [--dry-run] <command> ...
  wireguard-peers.py --selftest
"""

import argparse
import ipaddress
import json
import os
import re
import sys
import tempfile
from pathlib import Path

import yaml
from sops_lib import (
    read_recipients,
    read_recipients_from_text,
    run,
    sops_decrypt,
    sops_encrypt,
    write_atomic,
)

REPO_ROOT = Path(__file__).resolve().parent.parent
PEERS_JSON = REPO_ROOT / "global" / "wireguard-peers.json"
PEER_SECRETS = REPO_ROOT / "secrets" / "services" / "wireguard" / "secrets.yaml"
CLIENTS_SOPS = REPO_ROOT / "secrets" / "services" / "wireguard" / "clients.yaml"

DEFAULT_ENDPOINT = "vpn.kauderwels.ch"
DEFAULT_DNS = "10.0.0.1"
NAME_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*")


def load_peers(path: Path) -> dict:
    return json.loads(path.read_text())


def save_peers(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=2) + "\n")


def validate_name(name: str) -> None:
    if len(name) > 63 or not NAME_RE.fullmatch(name):
        raise ValueError(f"invalid peer name: {name!r}")


def find_peer(data: dict, name: str) -> dict | None:
    for peer in data.get("peers", []):
        if peer.get("name") == name:
            return peer
    return None


def tunnel_networks(server: dict) -> tuple[ipaddress.IPv4Network, ipaddress.IPv6Network]:
    v4 = v6 = None
    for entry in server["address"]:
        net = ipaddress.ip_network(entry, strict=False)
        if isinstance(net, ipaddress.IPv4Network) and v4 is None:
            v4 = net
        elif isinstance(net, ipaddress.IPv6Network) and v6 is None:
            v6 = net
    return v4, v6


def server_hosts(server: dict) -> list[ipaddress._BaseAddress]:
    return [ipaddress.ip_interface(entry).ip for entry in server["address"]]


def covered_networks(data: dict) -> list[ipaddress._BaseNetwork]:
    nets = []
    for peer in data.get("peers", []):
        for entry in peer.get("allowed_ips", []):
            nets.append(ipaddress.ip_network(entry, strict=False))
    for host in server_hosts(data["server"]):
        nets.append(ipaddress.ip_network(f"{host}/32" if host.version == 4 else f"{host}/128"))
    return nets


def allocate_tunnel_ips(server: dict, peers: list[dict]) -> tuple[str, str]:
    covered = covered_networks({"server": server, "peers": peers})
    out = []
    for net in tunnel_networks(server):
        for candidate in net.hosts():
            if any(candidate.version == c.version and candidate in c for c in covered):
                continue
            out.append(f"{candidate}/32" if candidate.version == 4 else f"{candidate}/128")
            break
        else:
            raise ValueError(f"no free tunnel address in {net}")
    return tuple(out)


def split_allowed_ips(allowed_ips: list[str], server: dict) -> tuple[list[str], list[str]]:
    tunnel_nets = tunnel_networks(server)
    tunnel, routes = [], []
    for entry in allowed_ips:
        net = ipaddress.ip_network(entry, strict=False)
        if any(net.version == t.version and net.subnet_of(t) for t in tunnel_nets):
            tunnel.append(entry)
        else:
            routes.append(entry)
    return tunnel, routes


def build_allowed_ips(tunnel_ips: list[str], routes: list[str]) -> list[str]:
    return list(tunnel_ips) + list(routes)


def resolve_endpoint(endpoint: str | None, listen_port: int) -> str:
    host = DEFAULT_ENDPOINT if endpoint is None else endpoint
    if host.rsplit(":", 1)[-1].isdigit() and ":" in host:
        return host
    return f"{host}:{listen_port}"


def render_client_conf(*, private_key: str, tunnel_ips: list[str], server: dict,
                       psk: str, endpoint: str | None, dns: str | None) -> str:
    return (
        "[Interface]\n"
        f"PrivateKey = {private_key}\n"
        f"Address = {', '.join(tunnel_ips)}\n"
        f"DNS = {dns or DEFAULT_DNS}\n"
        "\n"
        "[Peer]\n"
        f"PublicKey = {server['public_key']}\n"
        f"PresharedKey = {psk}\n"
        f"Endpoint = {resolve_endpoint(endpoint, server['listen_port'])}\n"
        "AllowedIPs = 0.0.0.0/0, ::/0\n"
        "PersistentKeepalive = 25\n"
    )


# ---------------------------------------------------------------------------
# sops layer (shared plumbing lives in scripts/sops_lib.py)
# ---------------------------------------------------------------------------

def _norm(data) -> dict:
    """Drop the sops metadata block so plaintext compares equal to decrypted."""
    data = dict(data or {})
    data.pop("sops", None)
    return data


def rule_recipients(rel_path: str, sops_config: Path = REPO_ROOT / ".sops.yaml") -> list[str]:
    """Age recipients the first matching creation rule in .sops.yaml declares for rel_path."""
    cfg = yaml.safe_load(sops_config.read_text()) or {}
    for rule in cfg.get("creation_rules", []):
        if re.search(rule["path_regex"], rel_path):
            out = []
            for grp in rule.get("key_groups", []):
                out.extend(grp.get("age", []))
            return out
    return []


def _verify_roundtrip(sops_file: Path, plaintext: str, age_key: Path) -> None:
    got = _norm(yaml.safe_load(sops_decrypt(sops_file, age_key)))
    want = _norm(yaml.safe_load(plaintext))
    if got != want:
        sys.exit(f"post-write verification failed for {sops_file}")


def sops_encrypt_existing(plaintext: str, sops_file: Path, age_key: Path) -> str:
    """Re-encrypt an existing file with its own embedded recipients."""
    recipients = read_recipients(sops_file)
    if not recipients:
        sys.exit(f"no age recipients found in {sops_file}")
    enc = sops_encrypt(plaintext, recipients)
    write_atomic(sops_file, enc)
    _verify_roundtrip(sops_file, plaintext, age_key)
    return enc


def sops_encrypt_new(plaintext: str, rel_path: str) -> str:
    """First write of a file: recipients come from the repo .sops.yaml rule."""
    env = {**os.environ, "SOPS_CONFIG": str(REPO_ROOT / ".sops.yaml")}
    with tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False) as tf:
        tf.write(plaintext)
        tmp_path = tf.name
    try:
        r = run(["sops", "--filename-override", rel_path, "-e", tmp_path], env=env)
    finally:
        os.unlink(tmp_path)
    if r.returncode != 0:
        sys.exit(f"sops -e (new) failed for {rel_path}: {r.stderr.strip()}")
    enc = r.stdout
    expected = set(rule_recipients(rel_path))
    produced = set(read_recipients_from_text(enc))
    if not produced or produced != expected:
        sys.exit(f"refusing to write {rel_path}: recipients {sorted(produced)} != "
                 f"rule {sorted(expected)}")
    return enc


def save_sops(sops_file: Path, plaintext: str, age_key: Path) -> str:
    """Encrypt + write + verify, choosing embedded vs .sops.yaml recipients."""
    if sops_file.exists():
        return sops_encrypt_existing(plaintext, sops_file, age_key)
    enc = sops_encrypt_new(plaintext, str(sops_file.relative_to(REPO_ROOT)))
    write_atomic(sops_file, enc)
    _verify_roundtrip(sops_file, plaintext, age_key)
    return enc


def _decrypt_sops(sops_file: Path, age_key: Path) -> dict:
    return _norm(yaml.safe_load(sops_decrypt(sops_file, age_key)))


# ---------------------------------------------------------------------------
# wg / qrencode layer (via nix-shell, like rotate-secrets.py's age-keygen)
# ---------------------------------------------------------------------------

def _nix_run(package: str, command: str, *, stdin: str | None = None) -> str:
    r = run(["nix-shell", "-p", package, "--run", command], stdin=stdin)
    if r.returncode != 0:
        sys.exit(f"{command} failed: {r.stderr.strip()}")
    return r.stdout


def wg_genkey() -> str:
    return _nix_run("wireguard-tools", "wg genkey").strip()


def wg_pubkey(priv: str) -> str:
    return _nix_run("wireguard-tools", "wg pubkey", stdin=priv.strip() + "\n").strip()


def wg_genpsk() -> str:
    return _nix_run("wireguard-tools", "wg genpsk").strip()


def qr_ansi(conf: str) -> str:
    return _nix_run("qrencode", "qrencode -t ansiutf8", stdin=conf)


# ---------------------------------------------------------------------------
# CLI helpers
# ---------------------------------------------------------------------------

def _age_key(args) -> Path:
    key = args.age_key or os.environ.get("SOPS_AGE_KEY_FILE")
    if not key:
        sys.exit("age key required: pass --age-key PATH or set SOPS_AGE_KEY_FILE")
    p = Path(key)
    if not p.exists():
        sys.exit(f"age key not found: {p}")
    return p


def _peer_names_in_sops(sops_file: Path) -> set[str]:
    """PSK names are YAML keys (sops encrypts values, not keys), so no key needed."""
    raw = yaml.safe_load(sops_file.read_text()) or {}
    return set(((raw.get("wireguard") or {}).get("peer") or {}).keys())


def _client_names(sops_file: Path) -> set[str]:
    if not sops_file.exists():
        return set()
    raw = yaml.safe_load(sops_file.read_text()) or {}
    return set((raw.get("clients") or {}).keys())


def _load_clients(age_key: Path) -> dict:
    if not CLIENTS_SOPS.exists():
        return {}
    return _decrypt_sops(CLIENTS_SOPS, age_key)


def _parse_csv(value: str | None) -> list[str]:
    if not value:
        return []
    return [v.strip() for v in value.split(",") if v.strip()]


def _validated_ips(entries: list[str]) -> list[str]:
    for entry in entries:
        try:
            ipaddress.ip_network(entry, strict=False)
        except ValueError:
            sys.exit(f"invalid CIDR: {entry!r}")
    return entries


def _psk_of(peer_secrets: dict, name: str) -> str | None:
    return ((peer_secrets.get("wireguard") or {}).get("peer") or {}).get(name)


def _server_peer_block(peer: dict, psk: str) -> str:
    return (
        "[Peer]\n"
        f"# {peer['name']}\n"
        f"PublicKey = {peer['public_key']}\n"
        f"PresharedKey = {psk}\n"
        f"AllowedIPs = {', '.join(peer['allowed_ips'])}\n"
    )


# ---------------------------------------------------------------------------
# CLI subcommands
# ---------------------------------------------------------------------------

def cmd_list(args) -> int:
    data = load_peers(PEERS_JSON)
    server = data["server"]
    psk_names = _peer_names_in_sops(PEER_SECRETS)
    client_names = _client_names(CLIENTS_SOPS)
    print(f"{'name':<12} {'v4':<16} {'v6':<22} {'routes':<22} {'psk':<4} key")
    for peer in data.get("peers", []):
        tun, routes = split_allowed_ips(peer["allowed_ips"], server)
        v4 = next((t for t in tun if ipaddress.ip_network(t, strict=False).version == 4), "-")
        v6 = next((t for t in tun if ipaddress.ip_network(t, strict=False).version == 6), "-")
        print(f"{peer['name']:<12} {v4:<16} {v6:<22} {','.join(routes) or '-':<22} "
              f"{'yes' if peer['name'] in psk_names else 'no':<4} "
              f"{'yes' if peer['name'] in client_names else 'no'}")
    return 0


def cmd_add(args) -> int:
    name = args.name
    validate_name(name)
    data = load_peers(PEERS_JSON)
    server = data["server"]
    if find_peer(data, name) or name in _peer_names_in_sops(PEER_SECRETS):
        sys.exit(f"peer already exists: {name}")

    if args.tunnel_ip:
        covered = covered_networks({"server": server, "peers": data.get("peers", [])})
        tunnel_ips = []
        for value in args.tunnel_ip:
            try:
                net = ipaddress.ip_network(value, strict=False)
            except ValueError:
                sys.exit(f"invalid tunnel IP: {value!r}")
            host = net.network_address
            if any(host.version == c.version and host in c for c in covered):
                sys.exit(f"tunnel IP {value} is already in use")
            tunnel_ips.append(f"{host}/32" if host.version == 4 else f"{host}/128")
    else:
        tunnel_ips = list(allocate_tunnel_ips(server, data.get("peers", [])))
    routes = _validated_ips(_parse_csv(args.routes))
    allowed_ips = build_allowed_ips(tunnel_ips, routes)

    client_meta: dict = {}
    if args.endpoint:
        client_meta["endpoint"] = args.endpoint
    if args.dns:
        client_meta["dns"] = args.dns

    if args.dry_run:
        print(f"[dry-run] add {name}")
        print(json.dumps({"name": name, "public_key": "<generated>",
                          "allowed_ips": allowed_ips}, indent=2))
        print(f"  sops: {PEER_SECRETS} <- wireguard/peer/{name}")
        print(f"  sops: {CLIENTS_SOPS} <- clients/{name} (private_key)")
        print(render_client_conf(private_key="<generated>", tunnel_ips=tunnel_ips,
                                 server=server, psk="<generated>",
                                 endpoint=args.endpoint, dns=args.dns))
        return 0

    age_key = _age_key(args)
    priv = wg_genkey()
    pub = wg_pubkey(priv)
    psk = wg_genpsk()

    peer = {"name": name, "public_key": pub, "allowed_ips": allowed_ips}

    peer_secrets = _decrypt_sops(PEER_SECRETS, age_key)
    peer_secrets.setdefault("wireguard", {}).setdefault("peer", {})[name] = psk
    save_sops(PEER_SECRETS, yaml.safe_dump(peer_secrets, sort_keys=False), age_key)

    clients = _load_clients(age_key)
    entry = {"private_key": priv}
    entry.update(client_meta)
    clients.setdefault("clients", {})[name] = entry
    save_sops(CLIENTS_SOPS, yaml.safe_dump(clients, sort_keys=False), age_key)

    save_peers(PEERS_JSON, {"server": server, "peers": data.get("peers", []) + [peer]})

    conf = render_client_conf(private_key=priv, tunnel_ips=tunnel_ips, server=server,
                              psk=psk, endpoint=args.endpoint, dns=args.dns)
    print(conf)
    print(qr_ansi(conf))
    print(f"\nPeer '{name}' added. Rebuild the WireGuard servers (buzz, jessie, pricklepants).")
    return 0


def cmd_show(args) -> int:
    data = load_peers(PEERS_JSON)
    server = data["server"]
    peer = find_peer(data, args.name)
    if peer is None:
        sys.exit(f"no such peer: {args.name}")

    if args.dry_run:
        tun, _ = split_allowed_ips(peer["allowed_ips"], server)
        print(f"[dry-run] show {args.name}")
        print(render_client_conf(private_key="<stored private key>", tunnel_ips=tun,
                                 server=server, psk="<stored psk>", endpoint=None, dns=None))
        return 0

    age_key = _age_key(args)
    psk = _psk_of(_decrypt_sops(PEER_SECRETS, age_key), args.name)
    entry = (_load_clients(age_key).get("clients") or {}).get(args.name)
    if entry and entry.get("private_key"):
        tun, _ = split_allowed_ips(peer["allowed_ips"], server)
        conf = render_client_conf(private_key=entry["private_key"], tunnel_ips=tun,
                                  server=server, psk=psk, endpoint=entry.get("endpoint"),
                                  dns=entry.get("dns"))
        print(conf)
        print(qr_ansi(conf))
    else:
        print(f"# peer '{args.name}' has no stored client key (legacy peer); "
              "server-side [Peer] block below", file=sys.stderr)
        print(_server_peer_block(peer, psk or "<no psk>"))
    return 0


def cmd_export(args) -> int:
    data = load_peers(PEERS_JSON)
    server = data["server"]
    peer = find_peer(data, args.name)
    if peer is None:
        sys.exit(f"no such peer: {args.name}")
    if args.name not in _client_names(CLIENTS_SOPS):
        sys.exit(f"peer '{args.name}' has no stored client key; cannot export")

    if args.dry_run:
        print(f"[dry-run] export {args.name} -> {args.out}")
        return 0

    age_key = _age_key(args)
    entry = (_load_clients(age_key).get("clients") or {}).get(args.name)
    if not entry or not entry.get("private_key"):
        sys.exit(f"peer '{args.name}' has no stored client key; cannot export")
    psk = _psk_of(_decrypt_sops(PEER_SECRETS, age_key), args.name)
    tun, _ = split_allowed_ips(peer["allowed_ips"], server)
    conf = render_client_conf(private_key=entry["private_key"], tunnel_ips=tun,
                              server=server, psk=psk, endpoint=entry.get("endpoint"),
                              dns=entry.get("dns"))
    Path(args.out).write_text(conf)
    print(f"wrote {args.out}")
    return 0


def cmd_update(args) -> int:
    data = load_peers(PEERS_JSON)
    server = data["server"]
    peer = find_peer(data, args.name)
    if peer is None:
        sys.exit(f"no such peer: {args.name}")

    new_name = args.name
    if args.new_name and args.new_name != args.name:
        validate_name(args.new_name)
        if find_peer(data, args.new_name) or args.new_name in _peer_names_in_sops(PEER_SECRETS):
            sys.exit(f"peer already exists: {args.new_name}")
        new_name = args.new_name

    new_allowed = list(peer["allowed_ips"])
    if args.allowed_ips:
        new_allowed = _validated_ips(_parse_csv(args.allowed_ips))
    if args.routes is not None:
        tun, _ = split_allowed_ips(new_allowed, server)
        new_allowed = build_allowed_ips(tun, _validated_ips(_parse_csv(args.routes)))
    tun, _ = split_allowed_ips(new_allowed, server)
    if not tun:
        sys.exit("update would remove all tunnel addresses from allowed_ips")

    if args.dry_run:
        print(f"[dry-run] update {args.name}")
        if new_name != args.name:
            print(f"  rename {args.name} -> {new_name} (JSON, sops peer, clients)")
        if new_allowed != peer["allowed_ips"]:
            print(f"  allowed_ips {peer['allowed_ips']} -> {new_allowed}")
        if args.rotate_psk:
            print("  rotate preshared key (sops)")
        if new_name == args.name and new_allowed == peer["allowed_ips"] and not args.rotate_psk:
            print("  (no changes)")
        return 0

    age_key = _age_key(args)

    if new_name != args.name or new_allowed != peer["allowed_ips"]:
        updated = {"name": new_name, "public_key": peer["public_key"], "allowed_ips": new_allowed}
        peers = [updated if p is peer else p for p in data["peers"]]
        save_peers(PEERS_JSON, {"server": server, "peers": peers})

    peer_secrets = _decrypt_sops(PEER_SECRETS, age_key)
    peer_map = peer_secrets.setdefault("wireguard", {}).setdefault("peer", {})
    psk_changed = False
    if new_name != args.name and args.name in peer_map:
        peer_map[new_name] = peer_map.pop(args.name)
        psk_changed = True
    if args.rotate_psk:
        peer_map[new_name] = wg_genpsk()
        psk_changed = True
    if psk_changed:
        save_sops(PEER_SECRETS, yaml.safe_dump(peer_secrets, sort_keys=False), age_key)

    if new_name != args.name and CLIENTS_SOPS.exists():
        clients = _decrypt_sops(CLIENTS_SOPS, age_key)
        cmap = clients.setdefault("clients", {})
        if args.name in cmap:
            cmap[new_name] = cmap.pop(args.name)
            save_sops(CLIENTS_SOPS, yaml.safe_dump(clients, sort_keys=False), age_key)

    print(f"Updated peer '{new_name}'. Rebuild the WireGuard servers.")
    return 0


def cmd_delete(args) -> int:
    data = load_peers(PEERS_JSON)
    server = data["server"]
    peer = find_peer(data, args.name)
    if peer is None:
        sys.exit(f"no such peer: {args.name}")

    has_client = args.name in _client_names(CLIENTS_SOPS)
    if args.dry_run:
        print(f"[dry-run] delete {args.name}")
        print("  JSON: remove peer")
        print(f"  sops: {PEER_SECRETS} <- remove wireguard/peer/{args.name}")
        if has_client:
            print(f"  sops: {CLIENTS_SOPS} <- remove clients/{args.name}")
        return 0

    age_key = _age_key(args)

    peer_secrets = _decrypt_sops(PEER_SECRETS, age_key)
    peer_map = (peer_secrets.get("wireguard") or {}).get("peer") or {}
    if args.name in peer_map:
        del peer_map[args.name]
        save_sops(PEER_SECRETS, yaml.safe_dump(peer_secrets, sort_keys=False), age_key)

    if CLIENTS_SOPS.exists():
        clients = _decrypt_sops(CLIENTS_SOPS, age_key)
        cmap = (clients.get("clients") or {})
        if args.name in cmap:
            del cmap[args.name]
            save_sops(CLIENTS_SOPS, yaml.safe_dump(clients, sort_keys=False), age_key)

    remaining = [p for p in data["peers"] if p is not peer]
    save_peers(PEERS_JSON, {"server": server, "peers": remaining})
    print(f"Deleted peer '{args.name}'. Rebuild the WireGuard servers.")
    return 0


def run_selftest() -> int:
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

    # name collision: JSON or sops names reserve a name
    data = {"server": server, "peers": [{"name": "test1", "allowed_ips": ["10.66.66.2/32"]}]}
    assert find_peer(data, "test1") is not None
    assert find_peer(data, "nope") is None

    # first-write recipient selection is separate from the existing-file path
    assert sops_encrypt_new is not sops_encrypt_existing  # distinct call paths

    # --routes are appended after the tunnel IPs
    assert build_allowed_ips(["10.66.66.3/32"], ["10.9.9.0/24"]) == ["10.66.66.3/32", "10.9.9.0/24"]

    # rendered client config ends with a trailing newline (export/QR path)
    assert render_client_conf(
        private_key="PRIV=", tunnel_ips=["10.66.66.2/32", "fd42:42:42::2/128"],
        server=server, psk="PSK=", endpoint=None, dns=None).endswith("\n")

    # first-write recipients come from the .sops.yaml rule, not the caller
    assert set(rule_recipients("secrets/services/wireguard/clients.yaml")) == {
        "age1yd27qq2ys4tyae08ncs09fqgma87asrd3kandkkyvdj0kgjn9v3qm3l0yu",
        "age1ex3axxazzhsllzj0pqkdgjqnvzjmp8he2patv0k5wlzaacqwpfys8saxrq",
        "age1f3fnr3dzn28xv52a3hht3d2ylpwrre3zghkh598syggaduq02dusfzsrmr",
    }

    print("selftest OK")
    return 0


def build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(description="WireGuard peer CRUD")
    ap.add_argument("--age-key", help="age key file (or set SOPS_AGE_KEY_FILE)")
    ap.add_argument("--dry-run", action="store_true", help="print the plan; write nothing")
    sub = ap.add_subparsers(dest="command", required=True)

    p = sub.add_parser("list", help="list peers")
    p.set_defaults(func=cmd_list)

    p = sub.add_parser("add", help="add a peer")
    p.add_argument("name")
    p.add_argument("--endpoint", help="endpoint host or host:port")
    p.add_argument("--dns", help="client DNS")
    p.add_argument("--routes", help="extra routed CIDRs, comma-separated")
    p.add_argument("--tunnel-ip", action="append", help="pin a tunnel IP (repeatable)")
    p.set_defaults(func=cmd_add)

    p = sub.add_parser("show", help="render a client config + QR")
    p.add_argument("name")
    p.set_defaults(func=cmd_show)

    p = sub.add_parser("export", help="write a client config to a file")
    p.add_argument("name")
    p.add_argument("--out", required=True, help="output file")
    p.set_defaults(func=cmd_export)

    p = sub.add_parser("update", help="update a peer")
    p.add_argument("name")
    p.add_argument("--rotate-psk", action="store_true", help="generate a new preshared key")
    p.add_argument("--new-name", help="rename the peer")
    p.add_argument("--allowed-ips", help="replace the peer's allowed IPs, comma-separated")
    p.add_argument("--routes", help="replace routed CIDRs, comma-separated")
    p.set_defaults(func=cmd_update)

    p = sub.add_parser("delete", help="delete a peer")
    p.add_argument("name")
    p.set_defaults(func=cmd_delete)
    return ap


def main() -> int:
    if "--selftest" in sys.argv[1:]:
        return run_selftest()
    args = build_parser().parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
