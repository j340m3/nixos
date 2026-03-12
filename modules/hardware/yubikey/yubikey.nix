{
  flake.modules.nixos.yubikey = {pkgs,...}:{
    services.yubikey-agent.enable = true;
    services.udev.packages = [ pkgs.libfido2 ];
  }
}
