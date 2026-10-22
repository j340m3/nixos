"""Shared sops + subprocess plumbing for the scripts/*.py helpers.

The three CLIs (wireguard-peers, rotate-secrets, publish-host-keys) all
shell out to sops the same way; this module holds that single copy.
"""

import os
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml


def run(cmd, *, env=None, stdin=None, capture_stdout=True, capture_stderr=True):
    """Run cmd, returning the CompletedProcess.

    capture_output=True would pipe stderr, which hides sudo's password
    prompt; when a caller needs the prompt to reach the terminal it passes
    capture_stderr=False (stdout stays captured).
    """
    return subprocess.run(
        cmd,
        capture_output=False,
        stdout=subprocess.PIPE if capture_stdout else None,
        stderr=subprocess.PIPE if capture_stderr else None,
        text=True,
        env=env,
        input=stdin,
        check=False,
    )


def sops_decrypt(sops_file: Path, age_key: Path | None = None) -> str:
    """Decrypt sops_file. age_key overrides $SOPS_AGE_KEY_FILE; None lets sops
    read the ambient key from $SOPS_AGE_KEY."""
    env = dict(os.environ)
    if age_key is not None:
        env["SOPS_AGE_KEY_FILE"] = str(age_key)
    r = run(["sops", "-d", str(sops_file)], env=env)
    if r.returncode != 0:
        sys.exit(f"sops -d failed for {sops_file}: {r.stderr.strip()}")
    return r.stdout


def read_recipients_from_text(text: str) -> list[str]:
    """Age recipients are public metadata in the encrypted YAML text."""
    data = yaml.safe_load(text) or {}
    age = (data.get("sops") or {}).get("age") or []
    return [entry["recipient"] for entry in age if entry.get("recipient")]


def read_recipients(sops_file: Path) -> list[str]:
    return read_recipients_from_text(Path(sops_file).read_text())


def sops_encrypt(plaintext_yaml: str, recipients: list[str]) -> str:
    """Encrypt plaintext_yaml for exactly recipients (empty -> '*').

    sops 3.x requires a .sops.yaml with creation_rules, so stage a temp one.
    NamedTemporaryFile(delete=False) creates atomically with O_EXCL and mode
    0o600 on POSIX, so the plaintext is never world-readable on /tmp.
    """
    with tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False) as cfg:
        cfg.write("creation_rules:\n")
        cfg.write("  - path: .*\n")
        cfg.write("    age:\n")
        for recip in recipients or ["*"]:
            cfg.write(f'      - "{recip}"\n')
        cfg_path = cfg.name
    try:
        env = {**os.environ, "SOPS_CONFIG": cfg_path}
        with tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False) as tf:
            tf.write(plaintext_yaml)
            tmp_path = tf.name
        try:
            r = run(["sops", "-e", tmp_path], env=env)
        finally:
            os.unlink(tmp_path)
        if r.returncode != 0:
            sys.exit(f"sops -e failed: {r.stderr.strip()}")
        return r.stdout
    finally:
        os.unlink(cfg_path)


def write_atomic(path: Path, content: str) -> None:
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(content)
    os.replace(tmp, path)
