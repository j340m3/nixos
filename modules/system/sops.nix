# dendritic aspect (ADR 0014): sops absorbed from _common/sops.nix.
{ inputs, ... }: {
  flake.modules.nixos.sops = {
    # self-sufficient: hosts that skip system-default (zurg) still get the
    # sops option class (normally borrowed via rate-limiting-avoidance)
    imports = [ inputs.sops-nix.nixosModules.sops ];
    sops.defaultSopsFile = ../../secrets/shared.yaml;
    #sops.age.generateKey = true;
  };
}
