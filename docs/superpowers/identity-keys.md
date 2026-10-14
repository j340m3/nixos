# Identity Keys & Secret Rotation

Two python3 scripts for managing host/service identity keys and sops secret rotation.

## publish-host-keys.py

Bootstrap a host's declarative SSH identity. Writes the host's ed25519 pub to
`secrets/common/ssh/<host>/<label>.pub` and stores the matching priv as
`<label>.key` in that host's sops `secrets.yaml` (encrypted, preserving all
existing age recipients). Replaces manual key copy+paste.

### Usage

```bash
# Read the host's live key via SSH
python3 scripts/publish-host-keys.py zurg --from-ssh zurg --age-key <local age key>

# Or read from a local priv file
python3 scripts/publish-host-keys.py pricklepants --priv /tmp/pricklepants-borg --age-key <local age key> --label borg:pricklepants
```

### Arguments

- `--from-ssh <target>` — SSH to `<target>` and read `/etc/ssh/ssh_host_ed25519_key`
- `--priv <file>` — read the ed25519 priv from a local file
- `--age-key <file>` — local copy of the host's sops age keyfile (NOT fetched over SSH)
- `--label <label>` — identity label (default: `ssh`). Pub goes to `secrets/common/ssh/<host>/<label>.pub`, priv to sops as `<label>.key` (colon → slash)
- `--sops-file <path>` — override the sops secrets.yaml path
- `--pub-out <dir>` — override the pub output dir (default: `secrets/common/ssh`)
- `--ssh-port <port>` — SSH port for `--from-ssh` (default: 42069)

### After running

Rebuild the host to pick up `services.openssh.hostKeys`:
```bash
nixos-rebuild --use-remote-sudo -H <host> switch
```

### Idempotency

Re-running with the same key is a no-op. The script detects when the stored
`ssh.key` already matches and skips.

---

## rotate-secrets.py

Rotate sops age keys, identity keys, and nebula certs for a host.

### age-key — rotate a host's sops age key

```bash
python3 scripts/rotate-secrets.py age-key pricklepants --age-key <current age key>
```

1. Generates a new age keypair
2. Re-encrypts the host's `secrets.yaml` with ONLY the new recipient (old keys can no longer decrypt)
3. Prints a deploy checklist

**After running:**
```bash
# Move the new age key to the host's sops.age.keyFile
cp <new key path> /path/to/host/keyfile
nixos-rebuild --use-remote-sudo -H pricklepants switch
# Verify
SOPS_AGE_KEY_FILE=<new key path> sops -d secrets/hosts/pricklepants/secrets.yaml
# Clean up the new key file after successful deploy
rm <new key path>
```

### identity — rotate an identity key (SSH host/build/borg key)

```bash
python3 scripts/rotate-secrets.py identity zurg ssh --age-key <host age key>
```

1. Generates a new SSH keypair
2. Replaces `<label>.key` in the host's sops file (preserving all existing age recipients)
3. Writes the pub to `secrets/common/ssh/<host>/<label>.pub`

**After running:**
```bash
nixos-rebuild --use-remote-sudo -H zurg switch
```

### nebula-cert — rotate a host's nebula cert + key

```bash
python3 scripts/rotate-secrets.py nebula-cert pricklepants \
  --ca-cert <local ca.crt> --ca-key <local ca.key> \
  --age-key <host age key>
```

1. Generates a new nebula keypair
2. Signs it with the CA (operator supplies local ca.crt + ca.key copies)
3. Replaces `nebula.self_key` + `nebula.self_crt` in the host's sops file

**After running:**
```bash
nixos-rebuild --use-remote-sudo -H pricklepants switch
```

The CA cert itself (`nebula.ca_crt`) is shared and rarely rotates. If it does,
that's a separate, heavier operation (regenerate CA → re-sign every host's
cert → redistribute).

### Arguments (common)

- `--age-key <file>` — local copy of the host's CURRENT sops age keyfile
- `--sops-file <path>` — override the sops secrets.yaml path
- `--networks <cidr>` — CIDR for the new nebula cert (default: `10.0.0.0/24`)

---

## Safety

- No private key is ever committed as plaintext
- All sops files remain `ENC[...]` encrypted in git
- Pub files (`secrets/common/ssh/.../*.pub`) are plaintext public keys
- Temp files are created with `NamedTemporaryFile(delete=False)` (mode 0o600,
  atomic via O_EXCL) and deleted in `finally` blocks
- The new age key in `age-key` rotation is intentionally kept as a deploy
  artifact (operator moves it to the host's keyFile and cleans up after deploy)