# nixos

Rolling-release-style NixOS + home-manager configurations, organized as a
single Nix flake. Each host is one folder; shared behavior lives in
`modules/`, per-user config in `modules/users/` and `modules/home/`.

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
| `flake.nix` | Inputs; the dendritic preset auto-imports `modules/` (see ADR 0014). |
| `modules/hosts/` | Host folders (each folder = one `nixosConfiguration`). |
| `modules/nix/` | flake-parts plumbing: `nixosConfigurations`, `homeConfigurations`, packages/checks/devShells, input manifest. |
| `modules/` | Feature modules (services, hardening, networking, ...), all auto-imported by `import-tree`. A `_` prefix excludes a file from auto-import; today only the `_constants.nix` data file uses it. |
| `modules/desktop/` | Reusable DE profiles (xfce, kde). |
| `modules/users/` | System user definitions. |
| `modules/home/` | home-manager configuration for `jeromeb`. |
| `modules/global/_constants.nix` | Cross-host constants (domain, nebula CIDR, build hosts). |
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
just docs-check            # check relative Markdown links
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

1. Create `modules/hosts/<name>/configuration.nix` (plus the host's
   `flake-parts.nix`, and any `facter.json`/disk config the host needs).
2. Import the aspects you need (`inputs.self.modules.nixos.<aspect>`, DE
   profile, `inputs.nixos-hardware.nixosModules.<board>`, ...).
3. Set `networking.hostName` and `system.stateVersion`.
4. Declare the host in `configuration.nix`:

   ```nix
   { inputs, ... }:
   {
     flake.modules.nixos."<name>" = { modulesPath, ... }: {
       imports = [ inputs.self.modules.nixos.system-default /* ... */ ];
       # host config
     };
   }
   ```

   `flake-parts.nix` only wires the configuration:

   ```nix
   { self, ... }:
   {
     flake.nixosConfigurations."<name>" = self.lib.mkNixos "x86_64-linux" "<name>";
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
