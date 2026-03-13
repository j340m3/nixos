{
  flake.modules.nixos.networking = {
    networking.nameservers = [ "1.0.0.1" "1.1.1.1" "8.8.8.8" "9.9.9.9" ];
    networking.useDHCP = true;
  }
}
