{
  inputs,
  ...
}:
{
  flake.modules.nixos.rex = {
    imports = with inputs.self.modules.nixos; [
      system-virtual
      systemd-boot
      xfce
    ];
  };
  ###
}
