#!/usr/bin/env python3
"""Rotate sops age keys, identity keys, and nebula certs for a host.

Four subcommands:
  age-key <host> [--age-key <current-keyfile>]
    Generate a new age keypair, re-encrypt the host's secrets.yaml with only
    the new recipient, print a deploy checklist.

  identity <host> <label> [--age-key <host-age-keyfile>]
    Generate a new SSH keypair, replace <label>.key in the host's sops file
    (preserving all existing age recipients), write the pub to
    secrets/common/ssh/<host>/<label>.pub.

  password <host> <user> [--key <sops-key>] [--password <pw>] [--age-key <host-age-keyfile>]
    Hash a login password to yescrypt and store it in the host's sops file
    (preserving existing age recipients). Pairs with users.users.<user>
    .hashedPasswordFile and users.mutableUsers = false so the change applies
    on rebuild. Prompts for the password unless --password is given (an
    argument is visible in `ps`).

  nebula-cert <host> --ca-cert <path> --ca-key <path> [--age-key <host-age-keyfile>] [--networks <cidr>]
    Generate a new nebula keypair, sign it with the CA, replace
    nebula/self_key + nebula/self_crt in the host's sops file (preserving
    existing age recipients). The CA cert+key are local copies supplied by
    the operator (they live on the CA host, not this host). --networks
    defaults to the address already on the host's cert, or the next free
    address in the mesh when the host has no cert yet.

--age-key is optional on every subcommand: if omitted the script lets sops
read the age key from $SOPS_AGE_KEY (raw content, set by the Justfile from
`rbw get age-key-nixos`). The script never fetches the age key over the
network.

Requires: python3, sops 3.x, ssh-keygen, nix-shell (for age-keygen + nebula-cert).
"""

import argparse
import getpass
import ipaddress
import json
import os
import re
import shutil
import sys
import tempfile
from pathlib import Path

import yaml
from sops_lib import read_recipients, run, sops_decrypt, sops_encrypt, write_atomic

REPO_ROOT = Path(__file__).resolve().parent.parent


def _resolve_age_key(arg) -> Path | None:
    """Resolve the host's sops age keyfile.

    --age-key wins; otherwise the script lets sops read the age key from
    $SOPS_AGE_KEY (raw content, set by the Justfile from
    `rbw get age-key-nixos`). The script never fetches the age key over the
    network.
    """
    if arg:
        return Path(arg)
    return None


def _age_keygen(new_key_path: str) -> str:
    """Generate a new age keypair. Returns the public key string."""
    if os.path.exists(new_key_path):
        os.unlink(new_key_path)
    cmd = [
        "nix-shell", "-p", "age", "--run",
        f"age-keygen -o {new_key_path}",
    ]
    r = run(cmd)
    if r.returncode != 0:
        sys.exit(f"age-keygen failed: {r.stderr.strip()}")
    # age-keygen writes the public key to stderr via nix-shell
    output = r.stdout + "\n" + r.stderr
    for line in output.splitlines():
        if line.startswith("Public key:"):
            return line[len("Public key:"):].strip()
    sys.exit("could not parse age public key from stdout/stderr")


def _ssh_keygen(priv_path: str, host: str, label: str):
    if os.path.exists(priv_path):
        os.unlink(priv_path)
    r = run([
        "ssh-keygen", "-t", "ed25519", "-N", "",
        "-f", priv_path, "-C", host,
    ])
    if r.returncode != 0:
        sys.exit(f"ssh-keygen failed: {r.stderr.strip()}")


def ssh_keygen_pub(priv_path: str) -> str:
    r = run(["ssh-keygen", "-y", "-f", priv_path])
    if r.returncode != 0:
        sys.exit(f"ssh-keygen -y failed: {r.stderr.strip()}")
    return r.stdout.strip()


def _label_key(label: str) -> str:
    return f"{label}.key"


def _set_nested(data: dict, key: str, value: str) -> None:
    """Set data["a"]["b"]["c"] from "a/b/c", creating intermediate dicts."""
    parts = key.split("/")
    node = data
    for part in parts[:-1]:
        node = node.setdefault(part, {})
    node[parts[-1]] = value


def _hash_password(password: str) -> str:
    """yescrypt ($y$) hash, matching what NixOS writes for hashedPassword."""
    r = run(["nix-shell", "-p", "mkpasswd", "--run", "mkpasswd -m yescrypt -s"],
            stdin=password)
    if r.returncode != 0:
        sys.exit(f"mkpasswd failed: {r.stderr.strip()}")
    for line in reversed(r.stdout.splitlines()):
        if line.startswith("$y$"):
            return line.strip()
    sys.exit(f"mkpasswd produced no yescrypt hash: {r.stdout!r}")


def _read_password(args) -> str:
    if args.password is not None:
        return args.password
    pw = getpass.getpass("new password: ")
    if pw != getpass.getpass("confirm password: "):
        sys.exit("passwords do not match")
    if not pw:
        sys.exit("empty password")
    return pw


def cmd_password(args) -> int:
    host = args.host
    user = args.user
    key = args.key or f"users/{user}/password_hash"
    age_key_path = _resolve_age_key(args.age_key)
    sops_file = (
        Path(args.sops_file)
        if args.sops_file
        else REPO_ROOT / "secrets" / "hosts" / host / "secrets.yaml"
    )
    if not sops_file.exists():
        sys.exit(f"sops file not found: {sops_file}")
    if age_key_path is not None and not age_key_path.exists():
        sys.exit(f"age key not found: {age_key_path}")

    recipients = read_recipients(sops_file)
    if not recipients:
        sys.exit(f"no age recipients found in {sops_file}")

    hashed = _hash_password(_read_password(args))

    plain = sops_decrypt(sops_file, age_key_path)
    data = yaml.safe_load(plain) or {}
    data.pop("sops", None)
    _set_nested(data, key, hashed)
    new_plain = yaml.safe_dump(data, default_flow_style=False, sort_keys=False)
    enc = sops_encrypt(new_plain, recipients)
    write_atomic(sops_file, enc)
    print(f"re-encrypted {sops_file} with {key}")

    verify = sops_decrypt(sops_file, age_key_path)
    node = yaml.safe_load(verify) or {}
    for part in key.split("/"):
        node = (node or {}).get(part)
    if node != hashed:
        sys.exit(f"post-rotation verification failed: {key} mismatch")
    print(f"post-rotation verification: {key} round-trip OK")

    print(f"\npassword set for {user} on {host}.")
    print(f"  rebuild: nixos-rebuild --use-remote-sudo -H {host} switch")
    return 0


def cmd_age_key(args) -> int:
    host = args.host
    age_key_path = _resolve_age_key(args.age_key)
    sops_file = (
        Path(args.sops_file)
        if args.sops_file
        else REPO_ROOT / "secrets" / "hosts" / host / "secrets.yaml"
    )
    if not sops_file.exists():
        sys.exit(f"sops file not found: {sops_file}")
    if age_key_path is not None and not age_key_path.exists():
        sys.exit(f"age key not found: {age_key_path}")

    recipients = read_recipients(sops_file)
    if not recipients:
        sys.exit(f"no age recipients found in {sops_file}")

    new_key_path = None
    try:
        with tempfile.NamedTemporaryFile("w", delete=False, suffix=".key") as nk:
            new_key_path = nk.name

        new_pub = _age_keygen(new_key_path)
        print(f"new age public key: {new_pub}")

        plain = sops_decrypt(sops_file, age_key_path)
        data = yaml.safe_load(plain) or {}

        # Drop all sops metadata — it will be regenerated by sops -e
        data.pop("sops", None)

        new_plain = yaml.safe_dump(data, default_flow_style=False, sort_keys=False)
        enc = sops_encrypt(new_plain, [new_pub])

        write_atomic(sops_file, enc)
        print(f"re-encrypted {sops_file} with new age recipient")

        verify = sops_decrypt(sops_file, Path(new_key_path))
        vdata = yaml.safe_load(verify) or {}
        if vdata.get("sops"):
            sys.exit("post-rotation verification failed: sops metadata leaked into plaintext")
        print("post-rotation verification: decrypt with new key OK")

        print(f"\nDeploy checklist for {host}:")
        print(f"  NEW AGE KEY:    {new_key_path} (MOVE TO host's sops.age.keyFile)")
        print(f"  DEPLOY:         nixos-rebuild --use-remote-sudo -H {host} switch")
        print(f"  VERIFY:         SOPS_AGE_KEY_FILE={new_key_path} sops -d {sops_file}")
        print(f"  CLEANUP:         rm {new_key_path} (after successful deploy)")
    finally:
        pass  # new_key_path is a deploy artifact; operator cleans up after deploy

    return 0


def cmd_identity(args) -> int:
    host = args.host
    label = args.label
    age_key_path = _resolve_age_key(args.age_key)
    sops_file = (
        Path(args.sops_file)
        if args.sops_file
        else REPO_ROOT / "secrets" / "hosts" / host / "secrets.yaml"
    )
    pub_out = Path(args.pub_out) if args.pub_out else REPO_ROOT / "secrets" / "common" / "ssh"
    if not sops_file.exists():
        sys.exit(f"sops file not found: {sops_file}")
    if age_key_path is not None and not age_key_path.exists():
        sys.exit(f"age key not found: {age_key_path}")

    recipients = read_recipients(sops_file)
    if not recipients:
        sys.exit(f"no age recipients found in {sops_file}")

    key_name = _label_key(label)

    with tempfile.NamedTemporaryFile("w", delete=False, suffix=".key") as nk:
        priv_path = nk.name

    try:
        _ssh_keygen(priv_path, host, label)
        priv_text = Path(priv_path).read_text()
        pub = ssh_keygen_pub(priv_path)

        plain = sops_decrypt(sops_file, age_key_path)
        data = yaml.safe_load(plain) or {}
        data.setdefault(label, {})[key_name] = priv_text
        new_plain = yaml.safe_dump(data, default_flow_style=False, sort_keys=False)
        enc = sops_encrypt(new_plain, recipients)
        write_atomic(sops_file, enc)
        print(f"re-encrypted {sops_file} with {key_name}")

        verify = sops_decrypt(sops_file, age_key_path)
        vdata = yaml.safe_load(verify) or {}
        stored = ((vdata.get(label) or {}).get(key_name))
        if stored != priv_text:
            sys.exit(f"post-rotation verification failed: {key_name} mismatch")
        print(f"post-rotation verification: {key_name} round-trip OK")

        pub_dir = pub_out / host
        pub_dir.mkdir(parents=True, exist_ok=True)
        pub_file = pub_dir / f"{label}.pub"
        pub_file.write_text(pub + "\n")
        print(f"wrote {pub_file}")

        print(f"identity rotated: {host}/{label} -> {pub_file}; rebuild {host}.")
    finally:
        if os.path.exists(priv_path):
            os.unlink(priv_path)

    return 0


def _mesh_cidr() -> str:
    """The nebula mesh CIDR, read from modules/global/_constants.nix."""
    txt = (REPO_ROOT / "modules" / "global" / "_constants.nix").read_text()
    m = re.search(r'nebula\.cidr\s*=\s*"([^"]+)"', txt)
    return m.group(1) if m else "10.0.0.0/24"


def _cert_networks(cert_text: str | None) -> list[str]:
    """The networks assigned to a nebula cert, via `nebula-cert print -json`."""
    if not cert_text:
        return []
    r = run(["nix-shell", "-p", "nebula", "--run",
             "nebula-cert print -path - -json"], stdin=cert_text)
    if r.returncode != 0:
        return []
    try:
        return json.loads(r.stdout)[0]["details"]["networks"] or []
    except (json.JSONDecodeError, KeyError, IndexError, TypeError):
        return []


def _host_cert(sops_file: Path, age_key) -> str | None:
    """This host's nebula/self_crt, or None if not decryptable."""
    plain = sops_decrypt(sops_file, age_key)
    data = yaml.safe_load(plain) or {}
    return (data.get("nebula") or {}).get("self_crt")


def _next_free_networks(age_key) -> str:
    """Lowest unused host address in the mesh CIDR, from existing certs."""
    net = ipaddress.ip_network(_mesh_cidr())
    used = set()
    for f in sorted((REPO_ROOT / "secrets" / "hosts").glob("*/secrets.yaml")):
        try:
            cert = _host_cert(f, age_key)
        except SystemExit:
            print(f"warning: could not decrypt {f}; skipping from IP scan",
                  file=sys.stderr)
            continue
        for n in _cert_networks(cert):
            try:
                used.add(ipaddress.ip_address(n.split("/")[0]))
            except ValueError:
                pass
    for ip in net.hosts():
        if ip not in used:
            return f"{ip}/{net.prefixlen}"
    sys.exit(f"no free host address in {net}")


def _default_networks(host: str, sops_file: Path, age_key) -> str:
    """Existing cert's IP if present, else the next free mesh address."""
    try:
        cert = _host_cert(sops_file, age_key)
    except SystemExit:
        cert = None
    nets = _cert_networks(cert)
    if nets:
        print(f"networks: {nets[0]} (from {host}'s existing cert)")
        return nets[0]
    proposed = _next_free_networks(age_key)
    print(f"networks: {proposed} (no existing cert; next free in mesh)")
    return proposed


def cmd_nebula_cert(args) -> int:
    host = args.host
    age_key_path = _resolve_age_key(args.age_key)
    ca_cert = Path(args.ca_cert)
    ca_key = Path(args.ca_key)
    sops_file = (
        Path(args.sops_file)
        if args.sops_file
        else REPO_ROOT / "secrets" / "hosts" / host / "secrets.yaml"
    )
    if not sops_file.exists():
        sys.exit(f"sops file not found: {sops_file}")
    if age_key_path is not None and not age_key_path.exists():
        sys.exit(f"age key not found: {age_key_path}")
    if not ca_cert.exists():
        sys.exit(f"CA cert not found: {ca_cert}")
    if not ca_key.exists():
        sys.exit(f"CA key not found: {ca_key}")

    recipients = read_recipients(sops_file)
    if not recipients:
        sys.exit(f"no age recipients found in {sops_file}")

    networks = args.networks
    if networks is None:
        networks = _default_networks(host, sops_file, age_key_path)

    tmpdir = tempfile.mkdtemp(prefix="nebula-rotate-")
    try:
        new_key = os.path.join(tmpdir, "nebula-self.key")
        new_pub = os.path.join(tmpdir, "nebula-self.pub")
        new_cert = os.path.join(tmpdir, "nebula-self.crt")

        # 1. Generate a new host keypair
        r = run(["nix-shell", "-p", "nebula", "--run",
                  f"nebula-cert keygen -out-key {new_key} -out-pub {new_pub}"])
        if r.returncode != 0:
            sys.exit(f"nebula-cert keygen failed: {r.stderr.strip()}")

        # 2. Sign it with the CA (name + networks required by nebula-cert sign)
        r = run(["nix-shell", "-p", "nebula", "--run",
                  (f"nebula-cert sign -ca-crt {ca_cert} -ca-key {ca_key} "
                   f"-in-pub {new_pub} -out-crt {new_cert} "
                   f"-name {host} -networks {networks}")])
        if r.returncode != 0:
            sys.exit(f"nebula-cert sign failed: {r.stderr.strip()}")

        new_key_text = Path(new_key).read_text()
        new_cert_text = Path(new_cert).read_text()

        # 3. Replace nebula.self_key + nebula.self_crt in the host's sops file
        #    (underscore convention, matching existing hosts' secrets.yaml)
        plain = sops_decrypt(sops_file, age_key_path)
        data = yaml.safe_load(plain) or {}
        data.setdefault("nebula", {})["self_key"] = new_key_text
        data.setdefault("nebula", {})["self_crt"] = new_cert_text
        new_plain = yaml.safe_dump(data, default_flow_style=False, sort_keys=False)
        enc = sops_encrypt(new_plain, recipients)
        write_atomic(sops_file, enc)
        print(f"re-encrypted {sops_file} with new nebula cert + key")

        # 4. Verify round-trip
        verify = sops_decrypt(sops_file, age_key_path)
        vdata = yaml.safe_load(verify) or {}
        vneb = vdata.get("nebula") or {}
        if vneb.get("self_key") != new_key_text or vneb.get("self_crt") != new_cert_text:
            sys.exit("post-rotation verification failed: nebula cert/key mismatch")
        print("post-rotation verification: nebula cert/key round-trip OK")

        print(f"\nnebula cert rotated for {host}:")
        print(f"  rebuild {host} to pick up the new cert + key.")
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)

    return 0


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Rotate sops age keys, identity keys, and nebula certs for a host"
    )
    sub = ap.add_subparsers(dest="command", required=True)

    p_age = sub.add_parser("age-key", help="rotate a host's sops age key")
    p_age.add_argument("host", help="nixos hostName")
    p_age.add_argument("--age-key", help="local copy of the host's CURRENT sops age keyfile; defaults to $SOPS_AGE_KEY_FILE")
    p_age.add_argument("--sops-file", help="override sops secrets.yaml path")

    p_id = sub.add_parser("identity", help="rotate an identity key (SSH etc.)")
    p_id.add_argument("host", help="nixos hostName")
    p_id.add_argument("label", help="identity label (e.g. ssh, build, borg:woody)")
    p_id.add_argument("--age-key", help="local copy of the host's sops age keyfile; defaults to $SOPS_AGE_KEY_FILE")
    p_id.add_argument("--sops-file", help="override sops secrets.yaml path")
    p_id.add_argument("--pub-out", help="override pub output dir (default: secrets/common/ssh)")

    p_pw = sub.add_parser("password", help="set a user's login password in a host's sops file")
    p_pw.add_argument("host", help="nixos hostName")
    p_pw.add_argument("user", help="user name")
    p_pw.add_argument("--key", help="sops key for the hash (default: users/<user>/password_hash)")
    p_pw.add_argument("--password", help="password to hash (omit to prompt; an argument is visible in `ps`)")
    p_pw.add_argument("--age-key", help="local copy of the host's sops age keyfile; defaults to $SOPS_AGE_KEY_FILE")
    p_pw.add_argument("--sops-file", help="override sops secrets.yaml path")

    p_neb = sub.add_parser("nebula-cert", help="rotate a host's nebula cert + key")
    p_neb.add_argument("host", help="nixos hostName")
    p_neb.add_argument("--ca-cert", required=True, help="local copy of the CA cert (ca.crt)")
    p_neb.add_argument("--ca-key", required=True, help="local copy of the CA key (ca.key)")
    p_neb.add_argument("--age-key", help="local copy of the host's sops age keyfile; defaults to $SOPS_AGE_KEY_FILE")
    p_neb.add_argument("--networks", default=None,
                       help="CIDR network/address for the new cert (default: "
                            "the host's existing cert IP, else the next free "
                            "address in the mesh)")
    p_neb.add_argument("--sops-file", help="override sops secrets.yaml path")

    args = ap.parse_args()

    if args.command == "age-key":
        return cmd_age_key(args)
    elif args.command == "identity":
        return cmd_identity(args)
    elif args.command == "password":
        return cmd_password(args)
    elif args.command == "nebula-cert":
        return cmd_nebula_cert(args)

    ap.print_help()
    return 1


if __name__ == "__main__":
    sys.exit(main())
