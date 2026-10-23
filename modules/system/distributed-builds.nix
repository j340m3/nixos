# dendritic: aspect with absorbed body (was modules/_common/distributed-builds.nix).
{ inputs, ... }:
let
  constants = import ../global/_constants.nix;
in
{
  flake.modules.nixos.distributed-builds =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      inventory = constants.buildHosts;
      peers = lib.filterAttrs (h: _: h != config.networking.hostName) inventory;
      sshBlock = h: host: ''
        Host ${h}
          HostName ${host}
          Port ${toString constants.sshPort}
          ConnectTimeout 3
        Match Host ${h} LocalUser root
          User remotebuild
          IdentitiesOnly yes
          IdentityFile /root/.ssh/remotebuild
      '';
      machines = lib.flatten (
        lib.mapAttrsToList (h: v: [
          {
            # Reticulum path is preferred; the ssh alias is handled by the shim.
            hostName = "${h}-rns";
            systems = v.systems or [ "x86_64-linux" ];
            speedFactor = 20;
            protocol = "ssh-ng";
            supportedFeatures = v.supportedFeatures or [ ];
            maxJobs = v.maxJobs or 4;
          }
          {
            # nebula path is the fallback.
            hostName = h;
            systems = v.systems or [ "x86_64-linux" ];
            speedFactor = 10;
            protocol = "ssh-ng";
            supportedFeatures = v.supportedFeatures or [ ];
            maxJobs = v.maxJobs or 4;
          }
        ]) peers
      );
    in
    {
      nix.distributedBuilds = true;
      nix.settings.builders-use-substitutes = true;
      nix.settings.substituters = lib.mkAfter (
        map (h: "ssh-ng://${h}-rns?trusted=1&max-connections=1") (lib.attrNames peers)
      );
      nix.buildMachines = machines;

      programs.ssh.extraConfig = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (h: v: sshBlock h v.connect) peers
      );

      # remotebuild user/group live in ../_remote-builder.nix (accept side),
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
    };
}
