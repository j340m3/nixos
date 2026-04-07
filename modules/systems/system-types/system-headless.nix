{
  inputs,
  config,
  lib,
  modulesPath
  ...
}:
{
  # expansion of default system with basic system settings & cli-tools

  flake.modules.nixos.system-headless = {
    imports = with inputs.self.modules.nixos; [
      system-minimal
      (modulesPath + "/profiles/minimal.nix")
      (modulesPath + "/profiles/headless.nix")
    ];

  };
}
