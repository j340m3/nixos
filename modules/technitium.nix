{...}:{
  services.technitium-dns-server = {
    enable = true;
    openFirewall = true;
  };
  
  # networking.firewall.allowedUDPPorts = [
  #   53 # technitium-dns-server
  # ];
  # networking.firewall.allowedTCPPorts = [
  #   53 # technitium-dns-server
  # ];
}
