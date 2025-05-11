{ config, pkgs, ... }:


{
  environment.systemPackages = with pkgs; [
    borgbackup
  ];

 services.minetest-server = {
   enable = true;
   port = 30000;
   gameId = "voxelibre";
   config = {
    enable_rollback = true;
    sprint_speed = 10;
    hudbars_autohide_stamina = false;
    address = "minetest.kauderwels.ch";
    remote_port = 30000;
    server_announce = false;
    server_name = "Bergmänners";
    server_description = "Se server wo se Bergmänner hosten";
    enable_damage = true;
    creative_mode = false;
    name = "kauderwelsch";
    enable_ipv6 = true;
    ipv6_server = true;
    enable_fire = true;
   };
 };
  networking.firewall.allowedTCPPorts = [ 30000 ];
  networking.firewall.allowedUDPPorts = [ 30000 ];

  sops.secrets."borg/luanti" = {
    #restartUnits = ["nebula@mesh.service"];
    #owner = "nebula-mesh";
    #group = "nebula-mesh";
    #path = "/etc/nebula/ca.crt";
    sopsFile = ../secrets/${config.networking.hostName}/secrets.yaml;
  };

  services.borgbackup.jobs.minetest = {
    paths = "/var/lib/minetest/.minetest";
    encryption.mode = "none";
    environment.BORG_RSH = "ssh -i ${config.sops.secrets."borg/luanti".path}";
    repo = "borg@10.0.0.3:.";
    compression = "auto,lzma";
    startAt = "daily";
  };

  # Send an email whenever auto upgrade fails
    systemd.services."borgbackup-job-minetest-start".onFailure =
      lib.mkIf config.systemd.services."notify-telegram@".enable
      [ "notify-telegram@%i.service" ];

}