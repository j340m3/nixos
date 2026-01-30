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
      ${rnspython} -m rnsd --service --verbose
    '';
    #script = ''
    #  ${pkgs.rns}/bin/rnsd
    #'';
    wantedBy = [ "multi-user.target" ];
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
