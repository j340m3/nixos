{ config, pkgs, lib, ... }:

{
  virtualisation.containers.enable = true;
  virtualisation.podman = { 
    enable = true;
    autoPrune = {
      enable = true;
      flags = [ "--all" ];
    };
  };
  virtualisation.oci-containers.backend = "podman";
  virtualisation.oci-containers.containers = {
    signald = {
      
    };
  };

  systemd.timers.update-containers = {
    timerConfig = {
      Unit = "update-containers.service";
      OnCalendar = "Mon 02:00";
    };
    wantedBy = [ "timers.target" ];
  };

  systemd.services.update-containers = {
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe (pkgs.writeShellScriptBin "update-containers" ''
        images=$(${pkgs.podman}/bin/podman ps -a --format="{{.Image}}" | sort -u)

        for image in $images; do
          ${pkgs.podman}/bin/podman pull "$image"
        done
      '');
    };
  };
}