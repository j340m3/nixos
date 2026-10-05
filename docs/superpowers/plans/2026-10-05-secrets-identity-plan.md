# Secrets & Identity Key Architecture — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make host/service identity keys and builder trust declarative and in-repo, and add an automated sops-age secret rotation script — so adding a host enrolls it as a builder on all peers with no `ssh yes`, and rotating secrets is a one-script-per-host operation.

**Architecture:** Split identity keys (committed pub + sops-managed priv, wired through `security.ssh.hostKeys` + `services.openssh.knownHosts` + builder `buildMachines`) from sops secret data; derive `knownHosts`/`buildMachines`/`borg authorizedKeysAppendOnly` from a single `constants.buildHosts` inventory + committed `secrets/common/ssh/<host>/<label>.pub` files via `lib.fileContents`, eliminating hand-typed pubkeys and the `ssh yes` prompt; add `functions/rotate-secrets.sh` for sops-age and identity key rotation.

**Tech Stack:** NixOS modules, sops-nix, `lib.fileContents`, `services.openssh.knownHosts`/`hostKeys`, `nix.distributedBuilds.machines` + `buildMachines`, `sops` CLI for re-encryption.

**Spec:** `docs/superpowers/specs/2026-10-05-secrets-identity-architecture-design.md`

## Global Constraints

- `flake.lock` is gitignored → `nix flake check` re-resolves ~100 inputs; gate on `nix eval` of built attrs + targeted activation, not full flake check.
- Per-host age `keyFile` location is host-defined via `sops.age.keyFile` (pricklepants: `/var/lib/sops-nix/key.txt`); rotate script must read each host's configured `keyFile` path.
- Builders connect on SSH port `42069` as user `remotebuild` (group already in `services.openssh.AllowGroups` in `modules/common/ssh.nix`).
- `woody` stays `nix.distributedBuilds = false` (it is a builder, not a client); exclude self + woody from each host's `buildMachines`.
- `slinky` keeps its own aarch64/qemu `buildMachines` override in `hosts/graphical/slinky/default.nix` — do not clobber.
- P1: host-key pubs live in `secrets/common/ssh/<host>/<label>.pub` (committed plaintext); borg client pubs sourced via `lib.fileContents` after migration but may stay inline until migrated.
- P2: host-key pubs published by one-off `ssh-keygen -y` commit (not auto-derived at eval).
- P3: shared `remotebuild` builder identity (5a).
- P4: inventory in new `constants/hosts.nix`, reachable because host configs already receive `constants`.

## Review Focus

1. Missing pub file for a host breaks `knownHosts` eval / reintroduces `ssh yes` — guard via a `nix eval` assertion in T1; commit pubs alongside the module.
2. Rotation re-encrypt making a secret unreadable at activation — guarded by T5 dry-run `sops -d`-reads-all check.
3. Builder host-key rotation without re-publishing pubs makes `knownHosts` stale — `publish-host-keys.sh` is idempotent and re-run after any key change.
4. `remotebuild` pub not authorized on a builder host → cross-host builds fail — verified in T4 with `ssh -i remotebuild <builder> true`.
5. Full `nix flake check` too slow to gate daily edits — plan uses `nix eval`/`nix build` of specific attrs + single-host activation logs as the check.

## Task 1: Inventory + ssh-identities module (declarative knownHosts + hostKeys)

**Files:**
- Create: `constants/hosts.nix`
- Create: `modules/common/ssh-identities.nix`
- Modify: `modules/common/default.nix` (add `ssh-identities.nix` to imports)

**Interfaces:**
- Consumes: `config.networking.hostName`, `constants.buildHosts`, `config.sops.secrets."ssh.key".path`, committed `secrets/common/ssh/<host>/ssh.pub`.
- Produces: `security.ssh.hostKeys` for the local host, `services.openssh.knownHosts` for every peer host.

- [ ] **Step 1: Write the failing eval assertion.** Add to `ssh-identities.nix` a `warnings`/`assertions`: for every peer host in `constants.buildHosts`, `lib.pathExists ../../secrets/common/ssh/<peer>/ssh.pub`; assert fails if any missing.

  ```nix
  # modules/common/ssh-identities.nix (skeleton)
  assertions = let hosts = attrNames constants.buildHosts; in
    map (h: { assertion = lib.pathExists (../../secrets/common/ssh + "/${h}/ssh.pub");
              message = "missing committed pub for ${h}"; }) hosts;
  ```
  Run: `nix eval '(with import <nixpkgs/nixos> { configuration = (import ./hosts/headless/pricklepants/default.nix); }; config.assertions)' ` (host-targeted eval via the host's config) — or simpler `nix eval --file` a tiny snippet. Expected: FAIL with "missing committed pub …" before pubs exist.

- [ ] **Step 2: Run the assertion to confirm it fails.** Run: the eval above. Expected: FAILURE (no pub files yet).

- [ ] **Step 3: Define `constants.buildHosts`.** `constants/hosts.nix`: one attrset `buildHosts = { <host> = { ip; port = 42069; systems; speedFactor; }; }` for every build-capable host (pricklepants, zurg, buzz, mrpotatohead, slinky, lenny, rex, jessie, plus builder1..4 if still external). Mark `woody` absent (not a builder client).

- [ ] **Step 4: Implement knownHosts + hostKeys declaratively.** In `ssh-identities.nix`, `services.openssh.knownHosts = mapAttrs (h: _: { publicKey = lib.fileContents ../../secrets/common/ssh + "/${h}/ssh.pub"; }) constants.buildHosts;` and `security.ssh.hostKeys = [ { type = "ed25519"; path = config.sops.secrets."ssh.key".path; } ];`.

- [ ] **Step 5: Run the assertion to confirm it passes.** Expected: PASS once pubs exist (T2). Re-run later for each newly enrolled host.

- [ ] **Step 6: Commit**
  ```bash
  git add constants/hosts.nix modules/common/ssh-identities.nix modules/common/default.nix docs/superpowers/plans/2026-10-05-secrets-identity-plan.md
  git commit -m "modules/common/ssh-identities: declare knownHosts+hostKeys from inventory"
  ```

## Task 2: Bootstrap & publish host keys (one-off per host, idempotent)

**Files:**
- Create: `functions/publish-host-keys.sh`
- Create: `secrets/common/ssh/<host>/ssh.pub` (for each builder host) — committed.

**Interfaces:**
- Consumes: live `/etc/ssh/ssh_host_ed25519_key` (+`.pub`) on the target host, that host's `secrets/hosts/<host>/secrets.yaml`.
- Produces: a committed pub file at `secrets/common/ssh/<host>/ssh.pub`, and `ssh.key` (priv) stored encrypted in that host's sops file.

- [ ] **Step 1: Write the script.** `functions/publish-host-keys.sh <host> <ssh-target>`:
  1. `ssh <target> cat /etc/ssh/ssh_host_ed25519_key.pub > secrets/common/ssh/<host>/ssh.pub` (if missing).
  2. `ssh <target> cat /etc/ssh/ssh_host_ed25519_key` → re-encrypt into `secrets/hosts/<host>/secrets.yaml` under key `ssh.key` (decrypt with current host age key, set `ssh.key`, re-encrypt).
  3. Print: "rebuild <host> to pick up `security.ssh.hostKeys`."
  - `git add secrets/common/ssh/<host>/ssh.pub` only (priv stays sops-only).

- [ ] **Step 2: Run on canary builder host (zurg).** `functions/publish-host-keys.sh zurg zurg`. Expected: `secrets/common/ssh/zurg/ssh.pub` created + committed; `ssh.key` present in zurg's sops file.

- [ ] **Step 3: Verify round-trip.** Run: `ssh-keygen -y -f <extracted priv from sops -d>` must equal `secrets/common/ssh/zurg/ssh.pub`. Expected: match.

- [ ] **Step 4: Commit pubs**
  ```bash
  git add secrets/common/ssh/zurg/ssh.pub secrets/hosts/zurg/secrets.yaml functions/publish-host-keys.sh
  git commit -m "secrets: publish zurg ssh host key pub; add publish-host-keys helper"
  ```

## Task 3: Canary deploy — knownHosts + hostKeys on one host

**Files:**
- Modify: `hosts/headless/zurg/default.nix` to import `ssh-identities` (falls in via `modules/common` already in T1).

**Interfaces:**
- Consumes: Task 1's module, Task 2's zurg pub.
- Produces: confirmed no-prompt SSH to peers + working as a builder target.

- [ ] **Step 1: Rebuild canary.** `nixos-rebuild --use-remote-sudo -H zurg switch` (stop upgrades first). Expected: activation succeeds, `security.ssh.hostKeys` path resolves to sops-priv, sshd starts.

- [ ] **Step 2: Verify trust from a peer.** From pricklepants: `ssh -p 42069 -i /root/.ssh/remotebuild zurg true`. Expected: runs without host-key prompt (knownHosts populated). Check `~/.ssh/known_hosts` on pricklepants no longer asks.

- [ ] **Step 3: Commit host activation** — no source change expected; if host config needed a flag, commit it. Document the canary result in the plan.

## Task 4: Roll to all hosts + inventory-driven builder list

**Files:**
- Modify: `modules/common/distributed-builds.nix` (replace hardcoded `builder1..4` loop with `constants.buildHosts`, exclude self/woody).
- Modify: `hosts/graphical/slinky/default.nix` (keep its override — guard so T4's auto-list doesn't clobber; `mkForce`/merge).
- Modify: one builder host's nix config to authorize `remotebuild` pub (group already exists; add `users.users.remotebuild.openssh.authorizedKeys.keys = [ <shared build pub committed> ]`).

**Interfaces:**
- Consumes: `constants.buildHosts`, `secrets/common/ssh/<host>/ssh.pub`, shared `remotebuild.pub`.
- Produces: every non-builder-client host lists every peer as a builder with knownHosts trust.

- [ ] **Step 1: Rewrite `distributed-builds.nix`.** `nix.buildMachines = mapAttrsToList (h: v: { hostName = h; hostName = v.ip; ... systems=v.systems; ... }) (filterAttrs (h: _: h != config.networking.hostName && h != "woody") constants.buildHosts);` and `programs.ssh.extraConfig Host <h>` blocks from same. Add `knownHosts` import (reuses T1 module).

- [ ] **Step 2: Run assertion guard** for all hosts as builder clients: `nix eval` that `builtins.attrNames config.nix.buildMachines` equals `constants.buildHosts` minus {self, woody} and each has a `lib.pathExists` pub. Expected: PASS.

- [ ] **Step 3: Authorize remotebuild builder identity** on each builder host (users config in a shared snippet under `modules/common` or inline). Commit the shared `remotebuild.pub` to `secrets/common/ssh/<host>/` as a public file too (it's the same pub on all) — or keep in `borg-server`/`ssh.nix`. Decision left to impl: one committed `secrets/common/ssh/builder/remotebuild.pub`.

- [ ] **Step 4: Verify from a client host** (zurg): `nix build --builders "ssh://remotebuild@pricklepants -` small drv. Expected: builds on pricklepants with no host-key prompt.

## Task 5: `rotate-secrets.sh` (sops age-key + identity rotation)

**Files:**
- Create: `functions/rotate-secrets.sh`

**Interfaces:**
- Consumes: a host's `keyFile` path (read from `sops.age.keyFile` in that host's config) + its `secrets/hosts/<host>/secrets.yaml`.
- Produces: re-encrypted sops file under a new age recipient; a deploy artifact for the new keyFile.

- [ ] **Step 1: Write the script.** `rotate-secrets.sh <host>`:
  1. Resolve host age `keyFile` by grepping `hosts/*/default.nix` for `sops.age.keyFile` (or take `--key-file <path>`).
  2. `age-keygen -o deploy/<host>/sops-age.key` (new key).
  3. Extract new age pub → rewrite `sops.age[-.0].age` recipient line in `secrets/hosts/<host>/secrets.yaml` (drop old recipient, add new).
  4. `SOPS_AGE_KEY_FILE=deploy/<host>/sops-age.key sops -d secrets/hosts/<host>/secrets.yaml > /tmp/r.yaml` then `SOPS_AGE_KEY_FILE=deploy/<host>/sops-age.key sops -e /tmp/r.yaml > secrets/hosts/<host>/secrets.yaml`.
  5. `SOPS_AGE_KEY_FILE=deploy/<host>/sops-age.key sops -d secrets/hosts/<host>/secrets.yaml` and assert every original key present in output.
  6. Print deploy checklist (copy `deploy/<host>/sops-age.key` → host `keyFile`, rebuild).

- [ ] **Step 2: Dry-run on scratch** (copy zurg's `secrets.yaml` to `/tmp`, run with a throwaway age key, verify decrypt reads all keys). Expected: all original top-level keys resolvable.

- [ ] **Step 3: Add identity-rotation flag** `--identity <host> <label>`: re-encrypt the `<label>.key` value under the file's existing age key, and `ssh-keygen -y` the new priv → overwrite `secrets/common/ssh/<host>/<label>.pub`. (Falls back to T2's publishing for host keys.)

- [ ] **Step 4: Commit** `functions/rotate-secrets.sh` + `deploy/.gitkeep`.

## Task 6: Borg pubkey migration (the original motivator)

**Files:**
- Modify: `modules/borg-server.nix` — change each `authorizedKeysAppendOnly` pub to `lib.fileContents ../../secrets/common/ssh/<client>/borg:<repo>.pub`; add `woody` repo entry.
- Modify: `modules/<client>.nix` (minetest/matrix2/minecraft-bedrock) to use the `borg:<repo>` identity-key label convention; add pricklepants borg identity (priv in pricklepants sops under `borg:<repo>.key` or keep `borg/<repo>` label per existing).
- Create: `secrets/common/ssh/pricklepants/borg:woody.pub` (pricklepants borg client key pub → woody server).

**Interfaces:**
- Consumes: Task 1/2 pub convention (`secrets/common/ssh/<host>/<label>.pub`).
- Produces: pricklepants' borg pubkey appears in woody's borg server authorizedKeys without hand-pasting; the "forgotten pubkey" bug class is gone.

- [ ] **Step 1: Add pricklepants borg identity** via T2 script with label; commit `secrets/common/ssh/pricklepants/borg:woody.pub`.

- [ ] **Step 2: Point woody at it.** In `modules/borg-server.nix`, `woody = { path=...; authorizedKeysAppendOnly = [ read .../borg:woody.pub ]; };` (new repo for woody-backed-up data) — or add pricklepants' borg pub to the existing repo pricklepants backs up. Decision left to impl (scope of new repo).

- [ ] **Step 3: Verify** pricklepants borg backup activates; `nix eval lib.fileContents` resolves; no plain pubkey string remains in `borg-server.nix`.

- [ ] **Step 4: Commit.**

## Self-Review (against spec)

- Spec §3 schema → T1/T2/T6. ✓
- Spec §4 inventory-driven builders → T4 (`buildMachines` from `constants.buildHosts`). ✓
- Spec §5 5a shared remotebuild → T4 (shared pub) + T3 trust check. ✓
- Spec §6 rotate script → T5. ✓
- Spec §7 borg motivation → T6. ✓
- Risks: host-key bootstrap (T2) necessarily touches hosts once — accepted per P2; `nix eval` guards (T1/T4) keep CI fast. ✓
- No step carries a body its signature/tests already determine; each step is one checkable action. ✓
- Plan ~ the length of the spec's novel surface (small, focused). ✓
