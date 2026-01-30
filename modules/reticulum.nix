{
  config,
  lib,
  pkgs,
  ...
}:
let
  rnspython = (
    pkgs.python3.withPackages (
      ps: with ps; [
        rns
        lxmf
      ]
    )
  );
in
{
  systemd.services.reticulum = {
    script = ''
      ${rnspython}/bin/rnsd --service --verbose
    '';
    #script = ''
    #  ${pkgs.rns}/bin/rnsd
    #'';
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Restart = "always";
      RestartSec = "3s";
    };
  };
  
  systemd.services.lxmf = {
    script = ''
      ${rnspython}/bin/lxmd --service --propagation-node
    '';
    #script = ''
    #  ${pkgs.rns}/bin/rnsd
    #'';
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Restart = "always";
      RestartSec = "3s";
    };
  };
  networking.firewall.allowedUDPPorts = [
    29716
    42671
  ];
  # Firewall seems to drop multicast packages
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -p udp -m pkttype --pkt-type multicast -m udp -j nixos-fw-accept
    ip6tables -A nixos-fw -p udp -m pkttype --pkt-type multicast -m udp -j nixos-fw-accept
  '';
}
