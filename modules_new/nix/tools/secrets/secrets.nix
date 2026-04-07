{
  inputs,
  self,
  ...
}:
{
  flake.modules.nixos.secrets =
    { pkgs, ... }:
    {
      imports = [ inputs.sops-nix.nixosModules.sops ];
      sops.defaultSopsFile = ../../../../secrets/example.yaml;
      # imports = [
      #   inputs.agenix.nixosModules.default
      # ];
      # environment.systemPackages = [ inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default ];
    };

  flake.modules.darwin.secrets =
    { pkgs, ... }:
    {
      imports = [ inputs.sops-nix.nixosModules.sops ];
      sops.defaultSopsFile = ../../../../secrets/example.yaml;
      # imports = [
      #   inputs.agenix.darwinModules.default
      # ];
      # environment.systemPackages = [ inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default ];
    };

  flake.modules.homeManager.secrets =
    { pkgs, ... }:
    {
      imports = [ inputs.sops-nix.homeManagerModules.sops ];
      # imports = [
      #   inputs.agenix.homeManagerModules.default
      # ];
    };

}
