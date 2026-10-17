{ pkgs, lib, config, constants, ... }:
let
  inventory = constants.buildHosts;
  peers = lib.filterAttrs (h: _: h != config.networking.hostName) inventory;
  # ygg backup address per peer (null until harvested from yggdrasilctl)
  yggAddr = h: constants.host.${h}.ygg or null;
  sshBlock = h: host: ''
    Host ${h}
      HostName ${host}
      Port ${toString constants.sshPort}
      User remotebuild
      IdentitiesOnly yes
      IdentityFile /root/.ssh/remotebuild
      ConnectTimeout 3
  '';
  machines = lib.flatten (
    lib.mapAttrsToList
      (h: v: [
        {
          # primary: nebula path wins via speedFactor; dials by alias so the
          # ssh-config block (not the raw IP) applies identity + port
          hostName = h;
          systems = v.systems or [ "x86_64-linux" ];
          speedFactor = 10;
          protocol = "ssh-ng";
          supportedFeatures = v.supportedFeatures or [ ];
          maxJobs = v.maxJobs or 4;
        }
      ]
      ++ lib.optionals (yggAddr h != null) [
          {
            hostName = "${h}-ygg";
            systems = v.systems or [ "x86_64-linux" ];
            speedFactor = 1; # backup path only
            protocol = "ssh-ng";
            supportedFeatures = v.supportedFeatures or [ ];
            maxJobs = v.maxJobs or 4;
          }
        ])
      peers
  );
in
{
  nix.distributedBuilds = true;
  nix.settings.builders-use-substitutes = true;
  nix.buildMachines = machines;

  programs.ssh.extraConfig = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (h: v: sshBlock h v.connect) peers
    ++ lib.concatMap (h: lib.optionals (yggAddr h != null) [ (sshBlock "${h}-ygg" (yggAddr h)) ]) (lib.attrNames peers)
  );

  # remotebuild user/group live in ../remote-builder.nix (accept side),
  # pulled in by nebula.nix for every mesh member.

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
