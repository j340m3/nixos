{ pkgs, config, lib, constants, ... }:
let
  inventory = constants.buildHosts;
  peers = lib.filterAttrs (h: _: h != config.networking.hostName && h != "woody") inventory;
in
{
  nix.distributedBuilds = true;
  nix.settings.builders-use-substitutes = true;

  nix.buildMachines = lib.mapAttrsToList (h: v: {
    hostName = v.connect;
    systems = v.systems or ["x86_64-linux"];
    speedFactor = v.speedFactor or 1;
    protocol = "ssh-ng";
    supportedFeatures = v.supportedFeatures or [];
    maxJobs = v.maxJobs or 4;
  }) peers;

  programs.ssh.extraConfig = lib.concatStringsSep "\n" (lib.mapAttrsToList (h: v: ''
    Host ${h}
      HostName ${v.connect}
      Port ${toString v.port}
      User ${v.user}
      IdentitiesOnly yes
      IdentityFile /root/.ssh/remotebuild
  '') peers);

  users.users.remotebuild = {
    isNormalUser = false;
    openssh.authorizedKeysFile = [ config.sops.secrets."remotebuild/pub".path ];
  };

  sops.secrets."remotebuild/key" = {
    sopsFile = ../../secrets/hosts/${config.networking.hostName}/secrets.yaml;
    owner = "root";
    group = "root";
    path = "/root/.ssh/remotebuild";
  };

  sops.secrets."remotebuild/pub" = {
    sopsFile = ../../secrets/hosts/${config.networking.hostName}/secrets.yaml;
    owner = "root";
    group = "root";
    path = "/root/.ssh/remotebuild.pub";
  };
}
