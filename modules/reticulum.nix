{config,lib,pkgs,...}:{
  systemd.services.reticulum = {
    path = with pkgs; [
      rns
    ];
    script = ''
      ${pkgs.rns}/bin/rnsd
    '';
    wantedBy = [ "multi-user.target" ];
  };

  # Firewall seems to drop multicast packages
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -p udp -m pkttype --pkt-type multicast -m udp -j nixos-fw-accept
    ip6tables -A nixos-fw -p udp -m pkttype --pkt-type multicast -m udp -j nixos-fw-accept
  ''
}