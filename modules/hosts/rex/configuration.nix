{
  inputs,
  ...
}:
{
  flake.modules.nixos.rex = {
    imports = with inputs.self.modules.nixos; [
      system-virtual
      system-graphical
      system-default
      systemd-boot
      xfce
    ];
  };
  ###
}
