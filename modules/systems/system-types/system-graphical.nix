{
  inputs,
  config,
  lib,
  ...
}:
{
  # expansion of default system with basic system settings & cli-tools

  flake.modules.nixos.system-graphical = {
    imports = with inputs.self.modules.nixos; [
      system-default
      stylix
    ];
  };
}
