{
  config,
  pkgs,
  lib,
  ...
}:
{
  #nix.distributedBuilds = false;
  nix.settings = {
    # substituters = ["https://cache-nix.project2.xyz/uconsole"];
    # trusted-substituters = ["https://cache-nix.project2.xyz/uconsole"];
    # trusted-public-keys = ["uconsole:t2pv3NWEtXCYY0fgv9BB8r9tRdK+Tz7HYhGq9bXIIck="];
    substituters = [
      "https://cache-nix.project2.xyz/uconsole"
      "https://cache.chaotic.cx"
    ];
    trusted-substituters = [
      "https://cache-nix.project2.xyz/uconsole"
      "https://cache.chaotic.cx"
    ];
    trusted-public-keys = [
      "uconsole:vvqOLjqEwTJBUqv1xdndD1YHcdlMc/AnfAz4V9Hdxyk="
      "chaotic.cachix.org-1:Zf7C6GVRqJjU8B/ihd+psPVKp3/7Or/FSvOP3/9aB8Y="
    ];

    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
  services.openssh.enable = true;
  boot.supportedFilesystems.zfs = false;

  environment.systemPackages = with pkgs; [
    wirelesstools
    iw
    gitMinimal
  ];

  # networking.wireless = {
  #   userControlled.enable = true;
  #   enable = true;
  # };
  # systemd.services.wpa_supplicant.wantedBy = mkOverride 50 [];
  # networking.networkmanager.enable = false;

  sops.secrets."users/j340m3/password_hash" = {
    sopsFile = ../../../secrets/hosts/slinky/secrets.yaml;
    neededForUsers = true;
  };

  # Managed declaratively so a password rotation applies on rebuild:
  # mutableUsers = true (the default) leaves an existing password untouched.
  users.mutableUsers = false;

  users.users.j340m3 = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    hashedPasswordFile = config.sops.secrets."users/j340m3/password_hash".path;
    packages = with pkgs; [
      firefox
      signal-desktop
    ];
  };
}
