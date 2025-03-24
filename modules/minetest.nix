{ config, pkgs, ... }:

{
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
}