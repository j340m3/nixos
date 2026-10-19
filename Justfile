set export

export SOPS_AGE_KEY := `rbw get age-key-nixos | xargs`
export AGE_PUBLIC_KEY := `rbw get age-key-nixos --field=username | xargs`

# --- secrets --------------------------------------------------------------

snano path: 
    sops edit $path

sops-refresh:
    sops refresh 

# python3 + pyyaml, since the shell's python3 lacks yaml.
# The age key is read from $SOPS_AGE_KEY (set above from rbw); --age-key optional.
# Usage: just py3 scripts/publish-host-keys.py zurg --from-ssh zurg
py3 *args:
    nix-shell -p python3 python3Packages.pyyaml --run "python3 {{ args }}" 

# --- nixos rebuilds -------------------------------------------------------

# Usage: just rebuild <host> [extra nixos-rebuild args]
rebuild host *args:
    nixos-rebuild switch --use-remote-sudo --flake .#{{host}} {{args}}

# Build without activating: just build <host>
build host *args:
    nixos-rebuild build --flake .#{{host}} {{args}}

# Stage the new config as next-boot default: just boot <host>
boot host *args:
    nixos-rebuild boot --use-remote-sudo --flake .#{{host}} {{args}}

# Test activation (reverts on reboot): just test <host>
test host *args:
    nixos-rebuild test --use-remote-sudo --flake .#{{host}} {{args}}

# --- checks & formatting --------------------------------------------------

# Evaluate every native NixOS configuration (no build). Catches broken
# imports/options. Skips hosts whose system differs from the current one
# (e.g. the aarch64 uConsole on an x86_64 machine).
check:
    #!/usr/bin/env bash
    set -uo pipefail
    system=$(nix eval --raw --impure --expr builtins.currentSystem)
    status=0
    for dir in modules/hosts/*; do
      [ -f "$dir/default.nix" ] || continue
      host=$(basename "$dir")
      hostSystem=$(nix eval --no-write-lock-file --raw ".#nixosConfigurations.${host}.config.nixpkgs.hostPlatform.system" 2>/dev/null)
      if [ "$hostSystem" != "$system" ]; then
        echo "skip  $host ($hostSystem)"
        continue
      fi
      if nix eval --no-write-lock-file --raw ".#nixosConfigurations.${host}.config.system.build.toplevel.drvPath" >/dev/null 2>"/tmp/nixos-check-${host}.err"; then
        echo "ok    $host"
      else
        echo "FAIL  $host"
        cat "/tmp/nixos-check-${host}.err"
        status=1
      fi
    done
    exit $status

# Format all tracked Nix files.
fmt:
    nix run .#formatter.x86_64-linux -- $(git ls-files '*.nix')

# Report formatting differences without writing (exit 1 if any).
fmt-check:
    nix run .#formatter.x86_64-linux -- --check $(git ls-files '*.nix')
