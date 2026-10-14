#!/usr/bin/env python3
"""WireGuard peer CRUD — pure core (validation, allocation, rendering).

Pure logic only: no sops, no `wg`, no network. The sops/wg CLI layer lives on
top of these functions (see functions/rotate-secrets.py for the CLI conventions).

Usage:
  wireguard-peers.py --selftest
"""

import ipaddress
import json
import re
import sys
from pathlib import Path

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


def main() -> int:
    if "--selftest" in sys.argv[1:]:
        return run_selftest()
    print("no subcommand (CLI added in a later task); try --selftest", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
