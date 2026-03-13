{
  flake.modules.nixos.networking =
    { lib, ... }:
    {
      networking.nameservers = [
        "1.0.0.1"
        "1.1.1.1"
        "8.8.8.8"
        "9.9.9.9"
      ];
      networking.useDHCP = lib.mkForce true;
      networking.networkmanager.enable = lib.mkForce true;
      networking.domain = "hosts.kauderwels.ch";
    };
}
