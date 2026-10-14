# Analysis: What from saylesss88.github.io (nix-book) is worth applying to this repo

## 1. Critical (Immediate Wins)

| # | Improvement | What to do | Pros | Cons | Effort |
|---|---|---|---|---|---|
| 1.1 | **README overhaul** | Expand `README.md` beyond "Rolling release style nixos configs". Cover: flake layout, how to build a host (`nixos-rebuild switch --flake .#<host>`), home-manager, secrets, Justfile, common workflows. | Onboarding, discoverability, prevents "what does this do?" questions. | None meaningful. | S |
| 1.2 | **HOSTS.md is minimal** | Flesh out `HOSTS.md`: per-host purpose (hardware class: laptop/desktop/server/VM), role (graphical/headless), users, specialisations, disk layout notes, remote IP/SSH notes (non-secret), status. | Great map for a multi-host flake. Matches book's "map your system" clarity. | Can drift if not updated. | S |
| 1.3 | **Flake `checks` for all hosts** | Add `checks.<system>.<host>-eval` that evaluates each `nixosConfiguration` (and `homeConfigurations`) with `pkgs.lib.nixosSystem`/`homeManagerConfiguration` eval only (no build). Catch broken imports/options on every change. | Catches regressions before rebuilds. Book stresses hermetic/eval clarity. Your superpowers already do eval loops; make it automatic. | Slight eval time in CI/local `nix flake check`. | S |
| 1.4 | **Keep `upgradeHealth.nix` but add eval check for enabled path** | You already implemented the opt-in module correctly. Add a check that when `enable=true` + custom `settleDelay`, timer/service exist with correct keys. Prevents accidental regressions to the script body. | Protects the auto-rollback you just built. | Trivial. | XS |
| 1.5 | **Document secrets workflow** | `docs/superpowers/identity-keys.md` exists. Link it from README + add a short "Secrets 101": when to use `publish-host-keys.py` vs `rotate-secrets.py`, `sops.yaml` rules, age key handling, `just py3 ...`, never committing privkeys. | Critical for sops-nix correctness (recipients). Prevents footguns. | Needs care not to leak hostnames/paths. | S |
| 1.6 | **Pinning discipline note** | The flake follows `inputs.<name>.follows = "nixpkgs"` for many things (stylix, apple-fonts, affinity-nix, comin). Document this choice + rationale in `flake.nix` comment or `docs/`. | Matches book's "explicit inputs + lockfile" reproducibility. | None. | XS |

## 2. High (Structure & Maintainability)

| # | Improvement | What to do | Pros | Cons | Effort |
|---|---|---|---|---|---|
| 2.1 | **Adopt flake-parts (dendritic-lite)** | Keep `nixosConfigurations`/`homeConfigurations` under `flake`, move `devShells`, `packages`, `formatter`, `checks`, `apps` to `perSystem`. Don't force a full rewrite. | Cleaner separation (system-agnostic vs arch-specific). Easier to grow. Auto-discovery of parts is already a pattern you considered. | Adds one input + small boilerplate. | M |
| 2.2 | **Add `perSystem.formatter = pkgs.nixfmt-tree` or `treefmt-nix`** | Add `formatter.x86_64-linux = pkgs.nixfmt-rfc-style` or use `treefmt-nix` to format Nix + Python + shell + md. Wire to `just fmt`/`nix fmt`. | Enforces consistent style. `nixfmt --check` exists in superpowers reports; make it default. | Minor bikeshed on style (you already use nixfmt). | S |
| 2.3 | **Add `devShells.default`** | Include tools used daily: `sops`, `age`, `ssh-to-age` (if used), `just`, `nixfmt`, `nixos-rebuild`, `jq`, `python3.withPackages (ps: [ps.pyyaml])`, `nix-tree`/`nix-du` optionally. | "Works on fresh clone" UX. Avoids ad-hoc `nix-shell -p ...`. | Small closure. | S |
| 2.4 | **Pre-commit with `pre-commit-hooks.nix`** | Add `pre-commit` devShell + `checks` (or just local). Hooks: `nixfmt`, `deadnix` (find unused bindings), `statix` (lint Nix), `shellcheck`, `ruff`/`pyupgrade` on `functions/*.py`. | Catches issues before commit. Pairs well with your verification-before-completion practice. | Can be annoying until tuned. | M |
| 2.5 | **Module options hygiene** | Many modules return `config = { ... }` with no `options`. For shared modules (`modules/common/*.nix`, `modules/*.nix`), add `options.<name>.enable` where sensible + `lib.mkOption` descriptions for user-facing knobs (e.g. `upgradeHealth.settleDelay` already good). | Self-documenting. `nixos-option`, `man configuration.nix`-style clarity. Matches module system explained in book. | Tedious to backfill wholesale. Do incrementally on touched modules. | L (incremental) |
| 2.6 | **Split large host `default.nix`** | `hosts/graphical/lenny/default.nix` is long. Split into `boot.nix`, `networking.nix`, `desktop.nix`, `users.nix` colocated with host. Keep `default.nix` as thin aggregator. | Easier to diff/reuse across hosts (rex/sid share patterns). | Mechanical churn. | M |
| 2.7 | **Centralize `permittedInsecurePackages`** | Seen in `flake.nix` (home), `modules/common/default.nix` (`radicle-node-1.10.3`). Consider single source of truth. | Single source of truth. | Low impact. | XS |
| 2.8 | **Use `specialArgs.constants` more** | Replace hardcoded strings (timezone "Europe/Berlin", locales, common paths) with `constants.*`. | DRY across hosts/users. | Must define constants safely. | S |
| 2.9 | **Type-check Python scripts lightly** | Add `pyright`/`mypy` (via devShell/pre-commit) + basic validation on `functions/*.py`. | Safer secret rotation/publishing. | Minimal. | S |

## 3. Medium (Nix Idioms from the Book)

| # | Improvement | What to do | Pros | Cons | Effort |
|---|---|---|---|---|---|
| 3.1 | **Apply "idiomatic Nix" small wins** | Prefer `let..in` over top-level `rec`, avoid `with`, use `lib` helpers consistently, avoid deep `//` on large attrsets unnecessarily. Scan touched files. | Readability, avoids common pitfalls. | Style-only. | S (spot fixes) |
| 3.2 | **Overlays: document `overlays/default.nix` intent** | If you add custom packages later, put overlays in `overlays/` and import via `nixpkgs.overlays = [ inputs.self.overlays.default ]`. Add structure only if needed. | Standard place for version overrides/local pkgs. | Only add if you actually override packages. | XS (structure only) |
| 3.3 | **Specialisations awareness** | Either use commented `specialisation` block in `lenny/default.nix` or remove comment to avoid confusion. | Avoids dead code. | Trivial. | XS |
| 3.4 | **Avoid `rec` in module attrsets** | Scan modules: prefer `let cfg = config.<opt>; in { ... }` or direct references. | Safer, matches idiomatic guidance. | Spot check only. | XS |
| 3.5 | **Use `mkEnableOption` consistently** | Convert ad-hoc `enable = mkOption { type = bool; default = false; }` to `mkEnableOption` over time. | Consistent UX + descriptions. | Mechanical. | Incremental |
| 3.6 | **Module `imports` ordering** | Group: hardware -> hardware-config -> local imports -> external modules -> feature modules -> DE/user. Document lightly if non-obvious. | Readability. | Cosmetic. | XS |

## 4. Medium-High (Operational & Safety)

| # | Improvement | What to do | Pros | Cons | Effort |
|---|---|---|---|---|---|
| 4.1 | **`nix flake check` in Justfile** | Add `check: nix flake check --no-build` (eval-only) or full. For this multi-host flake, eval-only is fast and catches most issues. | Fast feedback loop. Matches verification mindset. | Can be slow on first fetch; use `--no-build`. | XS |
| 4.2 | **`just rebuild <host>` shorthand** | Add recipes: `rebuild host:` `nixos-rebuild switch --use-remote-sudo --flake .#{{host}}` or local. Also `boot`, `test`. | DX win. You already have `py3`, `snano`. | Trivial. | XS |
| 4.3 | **`just fmt` recipe** | `fmt: nix fmt` (or `treefmt`). Pairs with formatter. | Consistent. | XS. | XS |
| 4.4 | **Health check integration test idea** | Add a tiny VM test (via `nixosTest`) that simulates a failing unit after switch: assert rollback triggers. | Proves the "rollback on failed units" path works. | VM tests are slow. Optional but valuable. | L |
| 4.5 | **Guard against `slinky` cross-arch eval noise** | In checks, only check configs whose `system` matches current `pkgs.system` in `checks` (or filter). | Avoids "expected failures" in `nix flake check`. | Slightly less coverage (can't eval foreign arch fully without emulation). | S |
| 4.6 | **Disk layout docs** | `hosts/*/hardware-configuration.nix` exists but disk setup is implicit. Add `disks.md` per host or inline comments. | Reproducible reinstalls. | Can drift. | S |
| 4.7 | **Impermanence: verify links** | If hosts use `impermanence.nix`, document which paths persisted/ephemeral. | Clarity + safe teardown/rebuilds. | Only if actually used. | S |
| 4.8 | **Nebula/sops integration sanity** | Add a short doc: age keyfile location per host, `sops.age.keyFile`, recipients model. | Pairs with your new scripts. | Low risk. | S |
| 4.9 | **Fail fast in Python scripts** | Add checks: ensure `sops` >=3.x, `ssh-keygen` present, repo root detection robust. | Defensive. | Cosmetic/low. | XS |

## 5. Nice-to-Have (Polish & Learning Alignment)

| # | Improvement | What to do | Pros | Cons | Effort |
|---|---|---|---|---|---|
| 5.1 | **`docs/` index** | Create `docs/README.md` linking: architecture, secrets, hosts, modules, superpowers, upgrade-health. | Easier navigation inside repo. | Trivial. | XS |
| 5.2 | **Module READMEs** | For complex modules (`modules/k3s.nix`, `modules/immich*.nix`, `modules/borg-server.nix`), add short header comment block: purpose, options, examples, dependencies. | Helps future-you + collaborators. | Incremental. | S |
| 5.3 | **Extract `functions/` to `scripts/`** | Rename to `scripts/` (contains Python executables). Update Justfile + docs. | Clear semantics. | Rename churn. | XS |
| 5.4 | **Add `nix flake show` to README** | Show outputs at a glance. | Quick sanity. | Cosmetic. | XS |
| 5.5 | **Track eval time lightly** | Add timing in Justfile (`time nix flake check --no-build`). | Awareness as flake grows. | None. | XS |
| 5.6 | **Adopt `nix-systems`** | Pull systems from `inputs.nix-systems`. DRY, cross-arch friendly. | DRY, cross-arch friendly. | Only matters if you build for multiple systems from same flake root. | S |
| 5.7 | **Link to nix-book from docs** | Add "Learning Nix" section in README/docs linking to https://saylesss88.github.io/ + official refs. | Internalizes knowledge source. | Trivial. | XS |

## 6. Micro-Optimizations

| # | Improvement | What to do | Pros | Cons | Effort |
|---|---|---|---|---|---|
| 6.1 | **Sort `imports` lists** | Lexicographic by path to reduce churn in diffs. | Tidier diffs. | Pure style. | XS |
| 6.2 | **Consistent `#` comments style** | Pick one style. | Consistency. | Cosmetic. | XS |
| 6.3 | **Remove commented blocks or explain** | Clean `lenny/default.nix` dead comments (specialisation, pkgsUnstable, etc.). | Less noise. | Might forget intent. | XS |
| 6.4 | **Add `description` to flake** | Add `description = "jeromeb's NixOS/home-manager flake";` to `flake.nix`. | Shows in `nix flake info`. | XS. | XS |

---

## Implementation status (this pass)

Done, in the agreed order:

1. `flake.nix` description + flake-parts migration (dendritic-lite): `flake.nixosConfigurations`/`homeConfigurations`, per-system `packages`/`checks`/`devShells`/`formatter`.
2. `README.md` overhaul; `HOSTS.md` expansion; `docs/` index; `docs/secrets-101.md`; `docs/disks.md`.
3. `Justfile`: `rebuild`/`build`/`boot`/`test`/`check`/`fmt`/`fmt-check`.
4. `devShells.default` (sops, age, just, nixfmt, jq, python+pyyaml, deadnix, statix, shellcheck) + `formatter`.
5. Eval checks: per-native-host `checks.x86_64-linux.<host>` + `checks.x86_64-linux.upgrade-health`.

### Bugs found while adding `nix flake check` / `just check`

- **Fixed:** `modules/borg-server.nix` read `../../secrets/...` (resolves to
  `/nix/store/secrets/...`) instead of `../secrets/...`. Broke evaluation of
  `woody` under pure eval.
- **Fixed:** `packages.x86_64-linux.image[-impermanent]`
  (`...build.diskoImages`) failed evaluation: `vmTools: the kernel argument
  (kernel-modules) has no target attribute`. Root cause: disko passes a module
  tree (`pkgs.aggregateModules [...]`) as vmTools' `kernel`, but newer nixpkgs
  requires a real kernel (with `.target`) there and wants module trees via
  `kernelModules`; disko (incl. master) has not been updated. Fix: a
  `nixpkgs.overlays` shim, scoped to the two image builders via
  `extendModules`, that tags `aggregateModules` results with
  `passthru.target = "bzImage"` (x86_64). Both image drvs now evaluate. This
  is an upstream lag; drop the shim once disko supports the new vmTools API.
- **Observation (not a bug):** `nix flake check --no-build` fails on
  `nixosConfigurations.zurg` at `programs.chromium.enable` with `path
  'base16-schemes-….drv' is not valid`. Cause: stylix/`base16.nix` reads the
  `base16-schemes` package at eval time (import-from-derivation), which
  `--no-build` forbids. `nix eval …toplevel.drvPath` and `nix build --dry-run`
  on the same host succeed. Pre-existing; `just check` (which does a plain
  eval) is unaffected.
- **Observation:** `.gitignore` lists `flake.lock`, so the lockfile is not
  committed. Decided with the maintainer: keep the rolling free-resolve; do
  not commit the lock.
