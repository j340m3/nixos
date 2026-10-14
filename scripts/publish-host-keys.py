#!/usr/bin/env python3
"""Bootstrap a host's declarative SSH identity (Approach 1, hybrid).

Writes the host's ed25519 SSH host-key pub to
`secrets/common/ssh/<host>/ssh.pub` (committed plaintext, consumed by
`modules/common/ssh-identities.nix` knownHosts via lib.fileContents)
and stores the matching priv as `ssh.key` in that host's sops
`secrets/hosts/<host>/secrets.yaml` (encrypted, recipients preserved).

Replaces manual key copy+paste between hosts. Requires: python3, sops 3.x, ssh-keygen, and a LOCAL copy of the host's
sops age keyfile (--age-key); the script never fetches the age key over the
network. sops 3.x needs a .sops.yaml creation_rules config for encryption;
this script writes a temp one automatically listing the target file's existing
age recipients so re-encryption preserves every recipient.

If the host's sops file carries MULTIPLE age recipients, --age-key must
point to a keyfile containing ALL of them (concatenated age identities)
so re-encryption preserves every recipient; otherwise sops drops the
others. A single-recipient file needs only that one key.

--age-key is optional: if omitted the script lets sops read the age key
from $SOPS_AGE_KEY (raw content, set by the Justfile from
`rbw get age-key-nixos`).

--from-ssh reads /etc/ssh/ssh_host_ed25519_key over SSH, running the
remote cat under `sudo` by default (the key is root-only; the password
prompt reaches your terminal). Use --no-sudo to read as the SSH user.
"""

import argparse
import os
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parent.parent
SSH_HOST_KEY_PATH = "/etc/ssh/ssh_host_ed25519_key"


def _run(cmd, *, env=None, capture=True, stdin=None, capture_stderr=True):
    # capture_output=True would also pipe stderr, which would hide sudo's
    # password prompt from the user. Pipe stdout always; stderr only when
    # the caller wants it captured.
    r = subprocess.run(
        cmd,
        capture_output=False,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture_stderr else None,
        text=True,
        env=env,
        input=stdin,
    )
    return r


def ssh_keygen_pub(priv_path: str) -> str:
    r = _run(["ssh-keygen", "-y", "-f", priv_path])
    if r.returncode != 0:
        sys.exit(f"ssh-keygen -y failed for {priv_path}: {r.stderr.strip()}")
    return r.stdout.strip()


def sops_decrypt(sops_file: Path, age_key: Path | None = None) -> str:
    env = dict(os.environ)
    if age_key is not None:
        env["SOPS_AGE_KEY_FILE"] = str(age_key)
    r = _run(["sops", "-d", str(sops_file)], env=env)
    if r.returncode != 0:
        sys.exit(f"sops -d failed for {sops_file}: {r.stderr.strip()}")
    return r.stdout


def sops_encrypt(plaintext_yaml: str, recipients: list[str]) -> str:
    # sops 3.x requires a .sops.yaml with creation_rules for encryption.
    # Stage a minimal one listing exactly the recipients we want to keep.
    with tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False) as cfg:
        cfg.write("creation_rules:\n")
        cfg.write("  - path: .*\n")
        cfg.write("    age:\n")
        for r in recipients or ["*"]:
            cfg.write(f"      - \"{r}\"\n")
        cfg_path = cfg.name
    try:
        env = {**os.environ, "SOPS_CONFIG": cfg_path}
        with tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False) as tf:
            tf.write(plaintext_yaml)
            tmp_path = tf.name
        try:
            r = _run(["sops", "-e", tmp_path], env=env)
        finally:
            os.unlink(tmp_path)
        if r.returncode != 0:
            sys.exit(f"sops -e failed: {r.stderr.strip()}")
        return r.stdout
    finally:
        os.unlink(cfg_path)


def read_recipients(sops_file: Path) -> list[str]:
    """Age recipients are public metadata in the encrypted file."""
    data = yaml.safe_load(sops_file.read_text()) or {}
    sops_meta = data.get("sops") or {}
    age = sops_meta.get("age") or []
    return [entry["recipient"] for entry in age if entry.get("recipient")]


def obtain_priv(args) -> tuple[str, bool]:
    """Return (priv_path, is_temp)."""
    if args.from_ssh:
        # /etc/ssh/ssh_host_ed25519_key is root-only. With --sudo the
        # remote cat runs under `sudo`; the password prompt reaches the
        # user's terminal because the ssh process inherits this process's
        # stdin (subprocess.run leaves stdin alone when not passed). With
        # capture_output=True stdout is still captured, so the key bytes
        # never hit the terminal. --no-sudo reads as the SSH user.
        prefix = "sudo " if args.sudo else ""
        cmd = [
            "ssh",
            "-p",
            str(args.ssh_port),
            args.from_ssh,
            f"{prefix}cat {SSH_HOST_KEY_PATH}",
        ]
        r = _run(cmd, capture_stderr=False)
        if r.returncode != 0:
            err = r.stderr or ""
            sys.exit(f"ssh read of {SSH_HOST_KEY_PATH} on {args.from_ssh} failed: {err.strip()}")
        with tempfile.NamedTemporaryFile("w", delete=False, suffix=".key") as tmp:
            tmp.write(r.stdout)
            priv_path = tmp.name
        os.chmod(priv_path, 0o600)
        return priv_path, True
    if args.priv:
        return str(args.priv), False
    sys.exit("need --priv <file> or --from-ssh <target>")


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Bootstrap a host's declarative SSH identity"
    )
    ap.add_argument("host", help="nixos hostName (also the sops file dir name)")
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--priv", help="path to the host's ed25519 SSH private key")
    src.add_argument("--from-ssh", help="ssh target to read the host key from")
    ap.add_argument("--ssh-port", type=int, default=42069, help="ssh port for --from-ssh")
    ap.add_argument("--sudo", action=argparse.BooleanOptionalAction, default=True,
                    help="run the remote cat under sudo (default: true); --no-sudo reads as the SSH user")
    ap.add_argument("--label", default="ssh", help="label for pub file and sops key (e.g. borg:pricklepants)")
    ap.add_argument("--age-key", help="local copy of the host's sops age keyfile; otherwise sops reads the age key from $SOPS_AGE_KEY (set by the Justfile from rbw)")
    ap.add_argument("--sops-file", help=f"override sops secrets.yaml path (default: secrets/hosts/<host>/secrets.yaml)")
    ap.add_argument("--pub-out", help=f"override pub output dir (default: secrets/common/ssh)")
    args = ap.parse_args()

    sops_file = (
        Path(args.sops_file)
        if args.sops_file
        else REPO_ROOT / "secrets" / "hosts" / args.host / "secrets.yaml"
    )
    pub_out = Path(args.pub_out) if args.pub_out else REPO_ROOT / "secrets" / "common" / "ssh"
    # --age-key overrides the keyfile path; otherwise sops reads the age key
    # from $SOPS_AGE_KEY (raw content, set by the Justfile from rbw).
    age_key = Path(args.age_key) if args.age_key else None

    priv_path, is_temp = obtain_priv(args)
    try:
        priv_text = Path(priv_path).read_text()

        # 1. Publish the pub (committed plaintext).
        pub = ssh_keygen_pub(priv_path)
        pub_dir = pub_out / args.host
        pub_dir.mkdir(parents=True, exist_ok=True)
        pub_file = pub_dir / args.label
        if pub_file.exists() and pub_file.read_text().strip() == pub:
            print(f"pub unchanged for {args.host}: {pub_file}")
        else:
            pub_file.write_text(pub + "\n")
            print(f"wrote {pub_file}")

        # 2. Store the priv under the label-derived key in the host's sops file (encrypted).
        if not sops_file.exists():
            sys.exit(f"sops file not found: {sops_file}")
        recipients = read_recipients(sops_file)
        plain = sops_decrypt(sops_file, age_key)
        data = yaml.safe_load(plain) or {}
        sops_key = args.label.replace(":", "/", 1)
        top_key, sub_key = sops_key.split("/", 1)
        existing = (data.get(top_key) or {}).get(sub_key)
        if existing == priv_text:
            print(f"{sops_key} already present for {args.host}; no-op")
            return 0
        data.setdefault(top_key, {})[sub_key] = priv_text
        new_plain = yaml.safe_dump(data, default_flow_style=False, sort_keys=False)
        enc = sops_encrypt(new_plain, recipients)
        tmp = sops_file.with_name(sops_file.name + ".tmp")
        tmp.write_text(enc)
        os.replace(tmp, sops_file)
        print(f"re-encrypted {sops_file} with {sops_key} for {args.host}")
        return 0
    finally:
        if is_temp:
            os.unlink(priv_path)


if __name__ == "__main__":
    sys.exit(main())
