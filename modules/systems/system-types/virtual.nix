{
  inputs, config, lib,
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
    boot.extraModulePackages = with config.boot.kernelPackages; [ virtualboxGuestAdditions ];
    systemd.services."virtualboxClientDragAndDrop" = {
      wantedBy = lib.mkForce [ ]; #Disable Drag and Drop
      #execStart=lib.mkForce [""];
    };
  };
}
