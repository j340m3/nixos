# nixos

Rolling-release-style NixOS + home-manager configurations, organized as a
single Nix flake. Each host is one folder; shared behavior lives in
`modules/`, per-user config in `users/` and `home/`.

## Quick start

```bash
# Build/switch a host defined in this flake
nixos-rebuild switch --use-remote-sudo --flake .#<host>

# Build without switching (test the build)
nixos-rebuild build --flake .#<host>

# Rebuild home-manager standalone (jeromeb)
home-manager switch --flake .#jeromeb
```

Host names come from `modules/hosts/*` (each folder declares itself as a
`nixosConfiguration` via its `flake-parts.nix`). See [HOSTS.md](./HOSTS.md) for
the host map.

## Layout

| Path | Purpose |
|---|---|
| `flake.nix` | Inputs; imports `modules/flake/` plumbing plus each host's `modules/hosts/<name>/flake-parts.nix`. |
| `modules/hosts/` | Host folders (each folder = one `nixosConfiguration`). |
| `modules/flake/` | flake-parts plumbing: `nixosConfigurations`, `homeConfigurations`, packages/checks/devShells. |
| `modules/` | Feature modules (services, hardening, networking, ...). |
| `modules/common/` | Modules imported by most hosts (ssh, sops, locale, update, ...). |
| `desktop-environments/` | Reusable DE profiles (xfce, kde, mate, ...). |
| `users/` | System user definitions. |
| `home/` | home-manager configuration for `jeromeb`. |
| `global/constants.nix` | Cross-host constants (domain, nebula CIDR, build hosts). |
| `secrets/` | sops-encrypted secrets + committed public keys. |
| `scripts/` | Host/service key + secret helper scripts. |
| `docs/` | Repo documentation (see [docs/README.md](./docs/README.md)). |
| `Justfile` | Convenience recipes (`just`). |

## Common workflows

```bash
just snano <path>          # sops edit a secret
just py3 scripts/...     # run a Python helper with pyyaml
just sops-refresh          # refresh sops metadata
just rebuild <host>        # nixos-rebuild switch --use-remote-sudo --flake .#<host>
just build <host>          # build without activating
just check                 # evaluate every native host (no build); catches broken imports/options
just fmt                   # format all tracked .nix files (nixfmt)
just fmt-check             # report formatting diffs without writing
```

`just check` is the fast eval gate; the flake also exposes per-host eval
checks at `checks.x86_64-linux.<host>` (build e.g.
`nix build .#checks.x86_64-linux.zurg`) plus `checks.x86_64-linux.upgrade-health`.

Formatting and checks are provided through [flake-parts](https://flake.parts/):
`nixosConfigurations`/`homeConfigurations` live under `flake`, while
`packages`/`checks`/`devShells`/`formatter` are `perSystem`.

Secrets, host identity keys, and rotation are documented in
[docs/secrets-101.md](./docs/secrets-101.md).

## Adding a host

1. Create `modules/hosts/<name>/` with a
   `default.nix` (and `hardware-configuration.nix`).
2. Import shared modules you need (`../../../modules/common`, DE profile, ...).
3. Set `networking.hostName` and `system.stateVersion`.
4. Declare the host: `modules/hosts/<name>/flake-parts.nix` with

   ```nix
   { self, ... }:
   {
     flake.nixosConfigurations."<name>" = self.lib.mkNixos "<name>";
   }
   ```

5. Add the host to [HOSTS.md](./HOSTS.md).

`flake.nix` imports every `modules/hosts/<name>/flake-parts.nix` it finds; a
folder without one is a loud eval error, not a silently skipped host — no
`flake.nix` edit needed.

## Inputs & pinning

All inputs follow `nixpkgs` where possible (`inputs.<name>.follows = "nixpkgs"`)
so the closure resolves against a single nixpkgs revision, pinned in
`flake.lock`. Bump with:

```bash
nix flake update                # all inputs
nix flake update <input>        # one input
```

## Learning Nix

See [docs/README.md](./docs/README.md#learning-nix) for references, including
[nix-book](https://saylesss88.github.io/), `nix.dev`, and the NixOS/Nixpkgs
manuals.
