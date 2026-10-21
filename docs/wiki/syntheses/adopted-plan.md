# Adopted plan (settled 2026-10-21)

Decisions recorded in [docs/adr/0014-dendritic-flake-parts-migration.md](../../adr/0014-dendritic-flake-parts-migration.md).
Mechanics knowledge: [../sources/flake-file.md](../sources/flake-file.md),
[../concepts/host-definition.md](../concepts/host-definition.md); full
current→target mapping table in
[./migration-plan-notes.md](./migration-plan-notes.md).

## Target tree

```
flake.nix                        # generated (DO-NOT-EDIT); only inputs manifest + dendritic outputs one-liner
modules/                         # 100% auto-imported (import-tree via flakeFile flakeModules.dendritic)
  nix/
    lib.nix                      # options.flake.lib (freeform) + mkNixos system, name  (aspect-keyed, no specialArgs)
    per-system.nix               # moved from modules/flake/, unchanged; systems = [ "x86_64-linux" ] preserved
    home-configurations.nix      # standalone-HM wrapper: mkHomeManager over the home/ aspects (custom pkgs handling)
    constants.nix                # from global/constants.nix — data aspect (generic class)
  system/                        # system-default base = former modules/common grab-bag; one feature file each
    update.nix, ssh.nix, locale.nix, sops.nix, zram.nix, ...        (+ system-default.nix as the aggregate)
  hosts/<name>/
    default.nix                  # flake.modules.nixos.<name> = imports of [ system-default + chosen features ] (+ host settings)
    flake-parts.nix              # one-liner: flake.nixosConfigurations = self.lib.mkNixos "<system>" "<name>"
    hardware-configuration.nix   # + host-local features, imported relatively by default.nix
  desktop/kde.nix, xfce.nix      # from desktop-environments/
  services/<name>.nix            # grafana, pihole, nextcloud, vaultwarden, loghost, minecraft-*(java|bedrock), ...
  home/<user>/
    style.nix, vscode.nix, browser.nix, accounts.nix, xfce.nix      # HM aspects: flake.modules.homeManager.*
  users/<name>.nix               # OS-account features (uid/groups/secrets mounts)
  /_-prefixed dirs               # parking drafts; excluded by import-tree
secrets/, scripts/               # data — stay outside modules/ (no .nix, verified 2026-10-21)
```

## flake-file workflow

- Generated flake.nix stays `mkFlake { inherit inputs; } (import-tree ./modules)`
  under the dendritic preset; feature modules access `inputs` via flake-parts
  args (`{ inputs, ... }`), never threaded into lower-level configs.
- Input declarations: `flake-file.inputs.<name>.{url, inputs.<dep>.follows}`,
  recursive depth OK, two nixpkgs entries fine, shallow params go in the URL
  string (`git+https://…?shallow=1` — recent Nix rejects typed `shallow`/`ref`
  attrs for the flake backend).
- Regen: `nix run .#write-flake` after any `flake-file.*` change;
  `checks.check-flake-file` (diff generated vs on-disk) runs automatically.
  **flake.lock is never rewritten by default**; leave auto-follow / lock
  rewriters OFF and transcribe the hand-tuned follows verbatim.
- Bootstrap before flake-file is lockable:

  ```
  nix-shell https://github.com/denful/flake-file/archive/main.tar.gz -A write-flake \
    --run write-flake --arg modules ./modules --argstr outputs flake-parts
  ```

  then transcribe inputs → regen → commit. New-input activation order:
  declare url → regen → `nix flake lock` → use it in a feature.

## Conversion recipe (per host)

1. Rename the host dir's `_default.nix` → `configuration.nix` and wrap its
   body: `{ lib, ... }: { flake.modules.nixos.<host> = { pkgs, ... }:
   { <verbatim body> }; }` — keep the body's original function head verbatim
   (its `inputs`/`constants` args resolve via the factory specialArgs, next
   point). Relative `../../../`/`./` imports stay as-is for now; they become
   `with self.modules.nixos;` aspect imports when the imported features
   exist. Sibling files keep `_`-prefixes (parked, host-local glue).
2. ~~`_module.args.{inputs,constants}` shims~~ **Superseded 2026-10-21**:
   shims recurse infinitely when an imported plain module references
   `inputs` in *imports* (e.g. `bootstrap/_default.nix`
   `imports = [ inputs.disko... ]`) — module-arg resolution then depends on
   `config` during module collection. Instead, `lib.mkNixos` passes
   `specialArgs = { inputs; constants; }` in aspect mode too (same value as
   the legacy branch); per-host heads need no shim lines. Drop specialArgs
   from the factory when the last plain sibling has converted.
3. The factory auto-switches: once `flake.modules.nixos.<host>` exists it
   evaluates in aspect mode — no change needed in the `flake-parts.nix`
   one-liner.
4. `just check` → green (includes `upgrade-health`, `peerpatrol`,
   `pre-commit` checks) → `just build <host>` → `just test <host>` on the
   live box (zurg) → `switch`. The check loop's host guard is the
   `flake-parts.nix` one-liner, so it keeps working for both idioms.
5. One commit per host. `mkNixos` factory gains a `system` parameter at
   skeleton time; old-style hosts keep working through it until their turn.

Tracer done 2026-10-21 (zurg): recipe above applied verbatim,
`nix build .#checks.x86_64-linux.zurg` + full `just check` green.
buzz done 2026-10-21 with the corrected recipe (step 2); `just check` green
(11 ok + aarch64 slinky skip). Remaining hosts: jessie, lenny,
mrpotatohead, pricklepants, rex, sid, slinky, woody, bootstrap(-impermanent)
last.

## Post-skeleton refactors (not part of host conversion)

- HM one-source (ADR §6): home/ tree → `home/jeromeb/*` aspects; standalone
  wrapper switches to `mkHomeManager` over the same aspects.
- Collector-style refactors where several hosts contribute per-identity data
  to one aspect: peerpatrol roster, nebula per-host IPs (constants merge).
- `modules/common` hard-enabled settings (reticulum, insecure-pkg allowlist)
  flow into `system-default` / `system-default`-like features.

## Done when

- flake.nix is generated and `checks.check-flake-file` passes.
- No host imports features by relative path; `specialArgs` gone from
  `mkNixos`; no `modules/common` aggregator.
- Aspects for all features; docs/wiki/index.md links this plan.

## Skeleton state (implemented 2026-10-21)

- Plumbing moved: `modules/flake/{lib,per-system,home}.nix` →
  `modules/nix/{lib,per-system,home-configurations}.nix`. `lib.nix` now
  declares `options.flake.lib` freeform and a two-arg
  `config.flake.lib.mkNixos = system: name:` that branches on
  `self.modules.nixos or { } ? ${name}` (aspect mode vs legacy
  `_default.nix` path import with transitional `specialArgs`).
- Every plain NixOS/HM file under `modules/` is parked with a `_`-prefix
  (files and the `common` dir only; root-level `users/`,
  `desktop-environments/`, `home/`, `global/`, `secrets/` needed nothing
  because import-tree never leaves `modules/`). One-liners assign the
  factory wrapper directly: `flake.nixosConfigurations = self.lib.mkNixos "x86_64-linux" "<name>"`.
- `modules/nix/inputs.nix` holds the input manifest (`flake-file.inputs.*`,
  follows transcribed verbatim — incl. `flake-parts.inputs.nixpkgs-lib.follows
  = "nixpkgs"`). `modules/nix/dendritic.nix` wires
  `inputs.flake-file.flakeModules.dendritic`.
- Deviation from the plan's bootstrap step: the denful bootstrap
  `nix-shell ... write-flake --arg modules` evaluates the tree WITHOUT
  mkFlake specialArgs, so any module with `{ inputs, ... }` functionArgs
  fails collection. Used instead: transcribe
  `flake.nix` (template shape + our inputs), `nix flake lock`, then
  `nix run .#write-flake` — the regenerated file became canonical and
  `checks.check-flake-file` guards drift from here on.
- ~~`just check`: 11/12 ok~~ Fixed same day, woody now green (12/12):
  nixpkgs 26.05 asserts `settings.security.secret_key != null` at eval
  time; the sops dotenv carries the key to grafana as
  `GF_SECURITY_SECRET_KEY`, so the module references it through grafana's
  env provider (`settings.security.secret_key = "$__env{GF_SECURITY_SECRET_KEY}"`)
  — key stays in sops, nothing leaks into the nix store. Also fixed a
  depth bug in the new staged `_home-assistant.nix`
  (`../secrets/...` → `../../../secrets/...` from `modules/hosts/woody/`).
  Conversion-phase note: sopsFile depths are file-location-sensitive
  (`modules/` → `../secrets`, `modules/_common/` → `../../secrets`,
  `modules/hosts/<h>/` → `../../../secrets`); moving a feature file to a
  `modules/<aspect>/` dir must adjust them.
