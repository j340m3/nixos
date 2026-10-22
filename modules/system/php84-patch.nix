# dendritic aspect (ADR 0014): temporary php2shell hotfix.
{ inputs, ... }:
{
  flake.modules.nixos.php84-patch = {
    # CVE-2026-109618/109619: nixos-unstable still ships php 8.4.26; serve the
    # patched 8.4.27 from nixpkgs-master (nixpkgs#576853, merged 2026-10-21).
    # Remove once `nix eval --raw nixpkgs/nixos-unstable#php84.version` is
    # 8.4.27+, after refreshing the nixpkgs input.
    nixpkgs.overlays = [
      (_final: prev: {
        php84 = inputs.nixpkgs-master.legacyPackages.${prev.system}.php84;
      })
    ];
  };
}
