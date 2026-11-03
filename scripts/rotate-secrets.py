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

  nebula-root [--transition] [--yes]
    Full root CA rotation (2026-11 design, see docs/secrets-101.md):
    generates a brand-new root CA (key lives only in a temp dir and is
    destroyed in the same run — accepted consequence: enrolling a mesh host
    later means re-running this rotation), re-signs the cert+key of every
    host under secrets/hosts/ (IsCA=false, 10-year validity, IP from
    global/constants.nix — lowest free address is allocated for hosts
    without one), and rewrites the sops files (per-host self_crt/self_key,
    shared.yaml nebula.ca_crt — old+new bundle with --transition, new-only
    without). Also unifies the mesh roster: lifts hosts.*.ip.nebula from
    secrets/shared.yaml into global/constants.nix (single source of truth),
    adds explicit per-roster-state `monitor` flags for peerpatrol,
    re-points peerpatrol.nix + per-system.nix at them, and adds zurg to the
    mesh (nebula+sops aspect imports). Dry-run by default; --yes applies
    and commits as one atomic commit (no push).

  nebula-root --retire-old-ca [--yes]
    After a --transition rotation: shrinks the nebula.ca_crt bundle in
    secrets/shared.yaml back to the single currently-used root (the newest
    one), once every host has picked up cert signed by it. No new certs.

--age-key is optional on every subcommand: if omitted the script lets sops
read the age key from $SOPS_AGE_KEY (raw content, set by the Justfile from
`rbw get age-key-nixos`). The script never fetches the age key over the
network.

Requires: python3, sops 3.x, ssh-keygen, nix-shell (for age-keygen + nebula-cert).
"""

import argparse
import datetime
import difflib
import getpass
import ipaddress
import json
import os
import re
import shlex
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


# --- nebula-root -----------------------------------------------------------

NEBULA_CA_NAME_PREFIX = "nixos-mesh-root"
NEBULA_CA_DURATION = "175200h"   # 20y — generous; the CA key dies right after signing
NEBULA_CERT_DURATION = "87600h"  # 10y per host cert

# Roster comment block in global/constants.nix that nebula-root owns (the
# "pending / lives in secrets/shared.yaml" wording becomes wrong after
# unification, so the rotation rewrites it too).
ROSTER_COMMENT_OLD = """  # Single mesh roster: host.<name>.ip = nebula address, endpoints = public
  # udp endpoints (lighthouses only), lighthouses = the relay/DNS backbone.
  # Certs remain the actual identity; only verified addresses go here
  # (lenny/rex/slinky pending - their ip.nebula lives in secrets/shared.yaml).
"""
ROSTER_COMMENT_NEW = """  # Single mesh roster: host.<name>.ip = nebula address, endpoints = public
  # udp endpoints (lighthouses only), lighthouses = the relay/DNS backbone.
  # Certs remain the actual identity; every roster host has an ip.
  # monitor = peerpatrol ping membership (false for laptops/new members).
  # Owns the mesh IPs formerly spread over secrets/shared.yaml
  # (hosts.<name>.ip/nebula): maintained by scripts/rotate-secrets.py
  # nebula-root.
"""

# peerpatrol only pings roster hosts with an ip; after unification it gets
# the explicit monitor flag instead, so laptops and keys-only members don't
# generate down-alert noise.
PEERPATROL_OLD = "      }) (lib.filterAttrs (_: h: h ? ip) constants.host);"
PEERPATROL_NEW = "      }) (lib.filterAttrs (_: h: h ? ip && h.monitor) constants.host);"

PER_SYSTEM_OLD = (
    "            assert 5 == lib.length "
    "(lib.filter (h: h ? ip) (lib.attrValues constants.host));"
)
PER_SYSTEM_NEW = (
    "            assert 5 == lib.length "
    "(lib.filter (h: h ? ip && h.monitor) (lib.attrValues constants.host));"
)


def _nc(*cli_args, stdin=None, fail="nebula-cert failed"):
    """Run nebula-cert, on PATH if available (Justfile py3 env) else via
    nix-shell -p nebula. Aborts the script on failure."""
    if shutil.which("nebula-cert"):
        r = run(["nebula-cert", *cli_args], stdin=stdin)
    else:
        shell = "nebula-cert " + " ".join(shlex.quote(a) for a in cli_args)
        r = run(["nix-shell", "-p", "nebula", "--run", shell], stdin=stdin)
    if r.returncode != 0:
        sys.exit(f"{fail}: {r.stderr.strip()}")
    return r.stdout


def _cert_meta(cert_text: str) -> dict:
    """First cert of `nebula-cert print -json` output for a PEM."""
    out = _nc("print", "-path", "-", "-json", stdin=cert_text,
              fail="nebula-cert print failed")
    return json.loads(out)[0]


def _pem_blocks(bundle_text: str) -> list[str]:
    """Split a (possibly concatenated) PEM bundle into single-PEM chunks."""
    blocks = re.findall(
        r"-----BEGIN [A-Z0-9 ]+-----.*?-----END [A-Z0-9 ]+-----\n?",
        bundle_text, flags=re.DOTALL)
    if not blocks:
        sys.exit("no PEM blocks found in CA bundle")
    return blocks


def _eval_roster() -> dict:
    """The host roster from global/constants.nix, evaluated by nix."""
    r = run(["nix", "eval", "--json", "-f",
             str(REPO_ROOT / "global" / "constants.nix"), "host"])
    if r.returncode != 0:
        sys.exit(f"nix eval of constants.nix failed: {r.stderr.strip()}")
    return json.loads(r.stdout)


def _roster_order(path: Path) -> list[str]:
    """Attribute order of the host roster block as written in the file (nix
    eval sorts keys alphabetically and would silently reorder the file)."""
    text = path.read_text()
    start = text.index("  host = {")
    end = text.index("\n  };\n", start)
    block = text[start:end]
    order = re.findall(r"^ {4}(\w+) = \{$", block, flags=re.MULTILINE)
    if not order:  # one-line/otherwise differently formatted block
        order = list(_eval_roster())
    return order


def _render_roster(roster: dict, order: list[str], monitored: set[str]) -> str:
    """Render the constants.nix host attrset nixfmt-style. New hosts are
    appended in `order`; existing entries keep endpoints/ip."""
    lines = ["  host = {"]
    for name in order:
        h = roster[name]
        lines.append(f"    {name} = {{")
        if h.get("ip"):
            lines.append(f'      ip = "{h["ip"]}";')
        endpoints = h.get("endpoints") or []
        if endpoints:
            lines.append("      endpoints = [")
            for ep in endpoints:
                lines.append(f'        "{ep}"')
            lines.append("      ];")
        lines.append(f'      monitor = {"true" if name in monitored else "false"};')
        lines.append("    };")
    lines.append("  };")
    return "\n".join(lines)


def _diff_text(before: str, after: str, label: str) -> str:
    """Unified diff of two file texts (or '' when unchanged)."""
    d = difflib.unified_diff(before.splitlines(), after.splitlines(),
                             fromfile=f"a/{label}", tofile=f"b/{label}",
                             lineterm="")
    return "\n".join(d)


def cmd_nebula_retire(args) -> int:
    """Remove all but the currently-used root from the shared ca_crt bundle."""
    shared = REPO_ROOT / "secrets" / "shared.yaml"
    plain = sops_decrypt(shared, None)
    data = yaml.safe_load(plain) or {}
    raw = ((data.get("nebula") or {}).get("ca_crt"))
    if not raw:
        sys.exit(f"no nebula.ca_crt in {shared}")

    blocks = _pem_blocks(raw)
    metas = []
    for b in blocks:
        try:
            m = _cert_meta(b)
        except SystemExit:
            print("warning: unparseable CA cert in bundle; treating as stale",
                  file=sys.stderr)
            continue
        if not m.get("details", {}).get("isCa"):
            print("warning: non-CA cert in ca_crt bundle; ignoring",
                  file=sys.stderr)
            continue
        metas.append((b, m))
    if not metas:
        sys.exit("CA bundle holds no parseable CA certs")

    def not_after(entry):
        d = entry[1]["details"]
        ts = d.get("notAfter") or d.get("not_after")  # v2 vs v1 json keys
        return datetime.datetime.fromisoformat(ts)

    # In a --transition bundle (old root kept alongside the new one), the
    # newest cert IS the new root: it is signed later than everything else
    # by construction.
    keep, keep_meta = max(metas, key=not_after)
    drop = [m for b, m in metas if b != keep]
    if not drop:
        print("CA bundle already holds only the root in use; nothing to retire.")
        return 0

    print("root CA rotation bundle in secrets/shared.yaml:")
    for b, m in metas:
        tag = "KEEP" if b == keep else "DROP"
        print(f"  [{tag}] {m['details']['name']}  notAfter={m['details']['notAfter']} "
              f"fp={m.get('fingerprint', '?')[:16]}")
    if not args.yes:
        print("\ndry-run: nothing changed. re-run with --yes to apply and commit.")
        return 0

    data["nebula"]["ca_crt"] = keep
    recipients = read_recipients(shared)
    enc = sops_encrypt(
        yaml.safe_dump(data, default_flow_style=False, sort_keys=False), recipients)
    write_atomic(shared, enc)
    check = yaml.safe_load(sops_decrypt(shared, None)) or {}
    kept_now = _pem_blocks(check["nebula"]["ca_crt"])
    if kept_now != [keep]:
        sys.exit("post-write verification failed: CA bundle mismatch")
    print(f"retired {len(drop)} old root CA(s); bundle now holds only "
          f"{keep_meta['details']['name']}.")

    run(["git", "-C", str(REPO_ROOT), "add", "secrets/shared.yaml"])
    r = run(["git", "-C", str(REPO_ROOT), "commit", "-m", "nebula: retire old root CA"])
    if r.returncode != 0:
        print(f"warning: git commit failed: {r.stderr.strip()}", file=sys.stderr)
        return 1
    print("committed as one atomic commit.")
    return 0


def _splice_constants(constants_text: str, roster_text: str) -> str:
    """Unification rewrite of global/constants.nix: expand the roster
    comment, then splice the rendered host attrset over the old one."""
    txt = constants_text.replace(ROSTER_COMMENT_OLD, ROSTER_COMMENT_NEW, 1)
    start = txt.index("  host = {")
    end = txt.index("\n  };\n", start) + len("\n  };")
    return txt[:start] + roster_text + txt[end:]


def _nebula_root_rotate(args) -> int:
    transition = bool(args.transition)
    apply = bool(args.yes)
    shared_yaml = REPO_ROOT / "secrets" / "shared.yaml"
    constants_nix = REPO_ROOT / "global" / "constants.nix"
    peerpatrol_nix = REPO_ROOT / "modules" / "system" / "peerpatrol.nix"
    per_system_nix = REPO_ROOT / "modules" / "nix" / "per-system.nix"
    zurg_cfg = REPO_ROOT / "modules" / "hosts" / "zurg" / "configuration.nix"

    # 1. Read all existing state up front (roster via nix eval; shared.yaml
    #    decrypted once — both IP sources before any byte is written).
    roster = _eval_roster()
    order = _roster_order(constants_nix)
    constants_text = constants_nix.read_text()
    shared_data = yaml.safe_load(sops_decrypt(shared_yaml, None)) or {}
    shared_data.pop("sops", None)
    hosts_secret_data = shared_data.get("hosts") or {}

    # 2. Targets: every host that ships a secrets/hosts/<h>/secrets.yaml.
    targets = sorted(p.parent.name for p in
                     (REPO_ROOT / "secrets" / "hosts").glob("*/secrets.yaml"))
    if not targets:
        sys.exit("no host secrets files found under secrets/hosts/")
    net = ipaddress.ip_network(_mesh_cidr())

    # 3. IP plan: roster wins, then lift from secrets/shared.yaml, then
    #    allocate the lowest free address. All three become the single
    #    roster in constants.nix; shared.yaml loses hosts.*.ip/nebula.
    used = {}
    for h, v in roster.items():
        if v.get("ip"):
            used[v["ip"].split("/")[0]] = h
    plan_bare: dict[str, str] = {}
    moved: dict[str, str] = {}
    allocated: dict[str, str] = {}
    for h in targets:
        if roster.get(h, {}).get("ip"):
            plan_bare[h] = roster[h]["ip"]
            continue
        lifted = (hosts_secret_data.get(h) or {}).get("ip", {}).get("nebula")
        if lifted:
            plan_bare[h] = lifted.split("/")[0]
            moved[h] = plan_bare[h]
        else:
            for ip in net.hosts():
                if str(ip) not in used:
                    plan_bare[h] = str(ip)
                    allocated[h] = plan_bare[h]
                    break
            else:
                sys.exit(f"no free mesh address left for {h}")
        if plan_bare[h] in used and used[plan_bare[h]] != h:
            sys.exit(f"IP {plan_bare[h]} for {h} is already taken by "
                     f"{used[plan_bare[h]]}")
        used[plan_bare[h]] = h
        if ipaddress.ip_address(plan_bare[h]) not in net:
            sys.exit(f"planned IP {plan_bare[h]} for {h} is outside {net}")

    # Monitor flags: the hosts peerpatrol *actually* watches today are the
    # roster entries already carrying an ip. New members start unmonitored.
    monitored = {h for h, v in roster.items() if v.get("ip")}

    new_roster = {}
    for h, v in roster.items():
        new_roster[h] = dict(v)
        new_roster[h]["ip"] = plan_bare[h]
    for h in targets:
        if h not in new_roster:
            new_roster[h] = {"ip": plan_bare[h]}
    new_order = order + [h for h in targets if h not in order]
    roster_text = _render_roster(new_roster, new_order, monitored)

    leftovers = [k for k, v in hosts_secret_data.items()
                 if isinstance(v, dict) and "nebula" in (v.get("ip") or {})
                 and k not in new_roster]

    # 4. Generate the new root + all host certs in a temp dir. The CA key is
    #    destroyed with the dir in every exit path (this is what makes the
    #    tool "rotation only" — a new host later needs a new full rotation).
    ca_name = f"{NEBULA_CA_NAME_PREFIX}-{datetime.datetime.now().astimezone().date():%Y%m%d}"
    tmpdir = tempfile.mkdtemp(prefix="nebula-root-")
    try:
        ca_crt_path = os.path.join(tmpdir, "ca.crt")
        ca_key_path = os.path.join(tmpdir, "ca.key")
        _nc("ca", "-name", ca_name, "-duration", NEBULA_CA_DURATION,
            "-out-crt", ca_crt_path, "-out-key", ca_key_path,
            fail="nebula-cert ca (root generation) failed")
        ca_text = Path(ca_crt_path).read_text()

        certs: dict[str, dict] = {}
        for h in targets:
            key_p = os.path.join(tmpdir, f"{h}.key")
            crt_p = os.path.join(tmpdir, f"{h}.crt")
            # One call generates the keypair and signs it; IsCA=false by
            # construction. (nebula-cert 1.11.2 has no lighthouse cert flag:
            # lighthouse-ness lives in config, not the cert.)
            _nc("sign", "-ca-crt", ca_crt_path, "-ca-key", ca_key_path,
                "-name", h, "-networks", f"{plan_bare[h]}/{net.prefixlen}",
                "-duration", NEBULA_CERT_DURATION,
                "-out-key", key_p, "-out-crt", crt_p,
                fail=f"nebula-cert sign failed for {h}")
            certs[h] = {"key": Path(key_p).read_text(),
                        "cert": Path(crt_p).read_text()}
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)

    # 5. Stage every rewrite (nix text edits + decrypted-sops rewrites).
    nix_stages = [{"path": constants_nix, "before": constants_text,
                   "after": _splice_constants(constants_text, roster_text)}]

    def stage_once(path: Path, old: str, new: str):
        text = path.read_text()
        if new in text:
            print(f"  {path.relative_to(REPO_ROOT)}: already unified (no edit)")
            return
        if old not in text:
            sys.exit(f"expected fragment not found in {path}:\n{old}")
        nix_stages.append({"path": path, "before": text,
                           "after": text.replace(old, new, 1)})

    stage_once(peerpatrol_nix, PEERPATROL_OLD, PEERPATROL_NEW)
    stage_once(per_system_nix, PER_SYSTEM_OLD, PER_SYSTEM_NEW)

    zurg_text = zurg_cfg.read_text()
    if "inputs.self.modules.nixos.nebula" in zurg_text:
        print("  modules/hosts/zurg/configuration.nix: already meshes (no edit)")
    elif "        inputs.self.modules.nixos.agent-md\n" not in zurg_text:
        sys.exit(f"expected agent-md import not found in {zurg_cfg}")
    else:
        nix_stages.append({
            "path": zurg_cfg,
            "before": zurg_text,
            "after": zurg_text.replace(
                "        inputs.self.modules.nixos.agent-md\n",
                "        inputs.self.modules.nixos.agent-md\n"
                "        # nebula mesh member; the aspect brings its sops wiring\n"
                "        inputs.self.modules.nixos.nebula\n"
                "        inputs.self.modules.nixos.sops\n",
                1),
        })

    sops_stages = []
    for h in targets:
        f = REPO_ROOT / "secrets" / "hosts" / h / "secrets.yaml"
        data = yaml.safe_load(sops_decrypt(f, None)) or {}
        data.pop("sops", None)
        data.setdefault("nebula", {})["self_key"] = certs[h]["key"]
        data["nebula"]["self_crt"] = certs[h]["cert"]
        sops_stages.append({
            "path": f,
            "plaintext": yaml.safe_dump(data, default_flow_style=False, sort_keys=False),
            "recipients": read_recipients(f),
            "desc": f"new nebula/self_key + nebula/self_crt (IP {plan_bare[h]})",
        })

    shared_neb = shared_data.setdefault("nebula", {})
    old_ca = shared_neb.get("ca_crt", "")
    shared_neb["ca_crt"] = (old_ca + "\n" + ca_text) if transition else ca_text
    dropped_nebula = []
    for hname in hosts_secret_data:
        node = hosts_secret_data.get(hname) or {}
        ipnode = node.get("ip") if isinstance(node, dict) else None
        if isinstance(ipnode, dict) and "nebula" in ipnode and hname in new_roster:
            del ipnode["nebula"]
            if not ipnode:
                node.pop("ip", None)
            dropped_nebula.append(hname)
    sops_stages.append({
        "path": shared_yaml,
        "plaintext": yaml.safe_dump(shared_data, default_flow_style=False, sort_keys=False),
        "recipients": read_recipients(shared_yaml),
        "desc": "nebula/ca_crt old+new bundle" if transition
                else "nebula/ca_crt old root dropped (hard cutover)",
    })

    # 6. Print the full plan.
    mode = "transition (old CA stays valid)" if transition else "hard cutover"
    print(f"== nebula-root rotation ({mode}) ==\n")
    print(f"new root CA  : {ca_name}  notAfter={_cert_meta(ca_text)['details']['notAfter']}")
    print("CA key       : temp dir only, destroyed after signing (nothing stored)")
    print(f"host certs   : {NEBULA_CERT_DURATION}, IsCA=false, no groups\n")
    print("IP plan:")
    for h in targets:
        src = ("roster" if roster.get(h, {}).get("ip") else
               "lifted from secrets/shared.yaml" if h in moved else
               "allocated (lowest free)")
        flag = "monitored" if h in monitored else "new member (unmonitored)"
        print(f"  {h:16} {plan_bare[h]:16} ({src},{flag})")
    print()
    print("cert preview:")
    for h in targets:
        m = _cert_meta(certs[h]["cert"])
        print(f"  {h:16} ip={m['details']['networks'][0]:16} "
              f"notAfter={m['details']['notAfter']} fp={m['fingerprint'][:12]}")
    print()
    if leftovers:
        print(f"note: stale hosts.*.ip/nebula left untouched in secrets/shared.yaml "
              f"(not rotation targets, not in roster): {', '.join(leftovers)}")
    print("\nnix edits:")
    for st in nix_stages:
        label = str(st["path"].relative_to(REPO_ROOT))
        d = _diff_text(st["before"], st["after"], label)
        if d:
            print(f"--- {label}")
            print(d)
    print("\nsops edits:")
    for st in sops_stages:
        print(f"  {st['path'].relative_to(REPO_ROOT)}: {st['desc']}")

    if not apply:
        print("\ndry-run complete: nothing written, no CA persisted. "
              "re-run with --yes to apply and commit.")
        return 0

    # 7. Apply: nix text first (verified by nix eval immediately), then the
    #    sops files, each with a decrypt round-trip check.
    for st in nix_stages:
        st["path"].write_text(st["after"])
        print(f"wrote {st['path'].relative_to(REPO_ROOT)}")

    got = _eval_roster()
    problems = []
    if set(got) != set(new_roster):
        problems.append(f"roster keys differ: {sorted(got)} vs {sorted(new_roster)}")
    for h in sorted(new_roster):
        want = new_roster[h]
        have = got.get(h) or {}
        if have.get("ip") != want.get("ip"):
            problems.append(f"{h}: ip {have.get('ip')} != {want.get('ip')}")
        if bool(have.get("monitor")) != (h in monitored):
            problems.append(f"{h}: monitor flag mismatch")
        if (have.get("endpoints") or None) != (want.get("endpoints") or None):
            problems.append(f"{h}: endpoints changed unexpectedly")
    if problems:
        sys.exit("constants.nix verification failed:\n  " + "\n  ".join(problems))
    print("constants.nix verified via nix eval (roster + monitor flags)")

    for st in sops_stages:
        enc = sops_encrypt(st["plaintext"], st["recipients"])
        write_atomic(st["path"], enc)
        check = yaml.safe_load(sops_decrypt(st["path"], None)) or {}
        check.pop("sops", None)
        if check != yaml.safe_load(st["plaintext"]):
            sys.exit(f"post-write verification failed for {st['path']}")
        print(f"re-encrypted {st['path'].relative_to(REPO_ROOT)} "
              f"(round-trip OK)")

    if any(st["path"] == zurg_cfg for st in nix_stages):
        r = run(["nix", "eval", "--raw", "--no-write-lock-file",
                 ".#nixosConfigurations.zurg.config.services.nebula.networks.mesh.ca"])
        if r.returncode != 0 or not r.stdout.strip():
            sys.exit(f"zurg eval verification failed: {r.stderr.strip()}")
        print(f"zurg fleet-wiring verified ({r.stdout.strip()})")

    # 8. One atomic commit, no push.
    files = sorted({str(st["path"].relative_to(REPO_ROOT)) for st in
                    nix_stages + sops_stages if st["path"].exists()})
    run(["git", "-C", str(REPO_ROOT), "add", *files])
    msg = f"nebula: rotate root CA, re-key {len(targets)} hosts"
    r = run(["git", "-C", str(REPO_ROOT), "commit", "-m", msg])
    if r.returncode != 0:
        sys.exit(f"git commit failed: {r.stderr.strip()}; changes are staged")
    print(f"committed: {msg}")

    print("\nnext steps (human):")
    print("  1. review:  git show --stat HEAD")
    print("  2. rebuild every mesh member, lighthouses first (just rebuild <host>)")
    print("  3. offline hosts (e.g. buzz) pick the new certs up on their next rebuild")
    if transition:
        print("  4. after all hosts run the new cert:")
        print("       just py3 scripts/rotate-secrets.py nebula-root --retire-old-ca --yes")
    return 0


def cmd_nebula_root(args) -> int:
    if getattr(args, "retire_old_ca", False):
        return cmd_nebula_retire(args)
    return _nebula_root_rotate(args)


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

    p_root = sub.add_parser("nebula-root",
                            help="rotate the nebula root CA and every host cert in one move")
    p_root.add_argument("--transition", action="store_true",
                        help="keep the old root in the nebula/ca_crt bundle so hosts "
                             "can be rolled out one by one (default: hard cutover)")
    p_root.add_argument("--retire-old-ca", action="store_true",
                        help="shrink the ca_crt bundle back to the root in use "
                             "(after a --transition rollout; generates no certs)")
    p_root.add_argument("--yes", action="store_true",
                        help="apply all changes and make one atomic commit "
                             "(default: dry-run)")

    args = ap.parse_args()

    if args.command == "age-key":
        return cmd_age_key(args)
    elif args.command == "identity":
        return cmd_identity(args)
    elif args.command == "password":
        return cmd_password(args)
    elif args.command == "nebula-cert":
        return cmd_nebula_cert(args)
    elif args.command == "nebula-root":
        return cmd_nebula_root(args)

    ap.print_help()
    return 1


if __name__ == "__main__":
    sys.exit(main())
