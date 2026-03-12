{
  inputs,
  ...
}:
{
  # expansion of default system with basic system settings & cli-tools

  flake.modules.nixos.virtual = {
    imports = with inputs.self.modules.nixos; [
      minimal
    ];
    virtualisation.diskSize = "auto";
    virtualisation.virtualbox.guest.enable = true;
  };
}
