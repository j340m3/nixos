{
  inputs,
  config,
  lib,
  ...
}:
{
  # expansion of default system with basic system settings & cli-tools

  flake.modules.nixos.system-headless =
    { modulesPath, ... }:
    {
      imports = with inputs.self.modules.nixos; [
        system-default
        (modulesPath + "/profiles/minimal.nix")
        (modulesPath + "/profiles/headless.nix")
      ];

    };
}
