# Secrets 101

This repo uses [sops-nix](https://github.com/Mic92/sops-nix) with [age](https://github.com/FiloSottile/age) for secret management. The helper scripts live in `functions/` and are invoked via the `Justfile`.

## Key concepts

- **Age keys**: Each host has its own sops age key (stored on the host as `sops.age.keyFile`). Public keys/recipients are tracked in `secrets/.sops.yaml` (or per-host rules) so that only authorized hosts/keys can decrypt.
- **Secrets layout**: Host-specific secrets live under `secrets/hosts/<host>/secrets.yaml` (encrypted). Shared/common assets (like published SSH pubkeys) live under `secrets/common/`.
- **Never commit private keys**: Private SSH keys, age private keys, or decrypted secrets must never be committed. Only public keys/metadata may be committed.
- **Recipiensts preserved**: When rotating/re-encrypting with the helper scripts, existing age recipients are preserved. If a file has multiple recipients, you must provide **all** of them (e.g. concatenate age identities) via `--age-key` or ensure `$SOPS_AGE_KEY` contains them.

## Workflow helpers

The Justfile sets `SOPS_AGE_KEY` from `rbw get age-key-nixos` and `AGE_PUBLIC_KEY` from the RBW entry. The `py3` recipe runs Python with `pyyaml` in a `nix-shell`.

### Publish host SSH identity

`functions/publish-host-keys.py` bootstraps a host's declarative SSH identity:
- Writes the host's ed25519 SSH pub to `secrets/common/ssh/<host>/<label>.pub` (committed, consumed by `modules/common/ssh-identities.nix`).
- Stores the matching priv as `<label>.key` in the host's `secrets/hosts/<host>/secrets.yaml` (encrypted). Default label is `ssh`.

Usage examples (via Justfile):
```bash
# Read live key via SSH (runs sudo remotely by default)
just py3 functions/publish-host-keys.py zurg --from-ssh zurg

# Read from local priv file
just py3 functions/publish-host-keys.py pricklepants --priv /tmp/pricklepants-borg --age-key /path/to/age-keys.txt --label borg:pricklepants
```

Key args: `--from-ssh <target>`, `--priv <file>`, `--age-key <file>` (local copy; never fetched over SSH), `--label <label>`, `--sops-file <path>`, `--pub-out <dir>`, `--ssh-port <port>`, `--no-sudo`. If `--age-key` is omitted, `$SOPS_AGE_KEY` is used.

After running: rebuild the host to pick up `services.openssh.hostKeys` (e.g. `nixos-rebuild --use-remote-sudo -H <host> switch`). Re-running with the same key is idempotent.

### Rotate secrets/keys

`functions/rotate-secrets.py` rotates age keys, identity keys, or nebula certs for a host.

**Rotate a host's sops age key:**
```bash
just py3 functions/rotate-secrets.py age-key pricklepants --age-key <current age key>
```
1. Generates a new age keypair.
2. Re-encrypts the host's `secrets.yaml` with **only** the new recipient.
3. Prints a deploy checklist. Move the new age key to the host's `sops.age.keyFile`, rebuild, verify with `sops -d`, then remove the temp new key.

**Rotate an identity key (SSH host/build/borg key):**
```bash
just py3 functions/rotate-secrets.py identity zurg ssh --age-key <host age key>
```
1. Generates a new SSH keypair.
2. Replaces `<label>.key` in the host's sops file (preserving all existing age recipients).
3. Writes the pub to `secrets/common/ssh/<host>/<label>.pub`.

See `docs/superpowers/identity-keys.md` for the full reference and more examples.

## Safety rules
- Use local copies of age keys (`--age-key`); the scripts do not fetch them over the network.
- If a secrets file has multiple age recipients, ensure your `--age-key` file contains **all** of them (concatenated) so re-encryption preserves every recipient.
- sops 3.x requires creation rules; the scripts auto-generate a temporary `.sops.yaml` listing the recipients to preserve.
- Edit secrets with `just snano <path>` (which runs `sops edit ...`).
