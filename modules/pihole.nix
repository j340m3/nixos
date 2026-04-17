{ ... }:
{
  services.adguardhome = {
    enable = true;
    settings = {
      dns.bind_hosts = [
        "0.0.0.0"
      ];
      anonymize_client_ip = true;
      filtering_enabled = true;
      upstream_dns = [
        "tls://dns3.digitalcourage.de"
        "tls://dot.ffmuc.net"
        "tls://dns.digitale-gesellschaft.ch"
        "https://doh.ffmuc.net/dns-query"
        "https://dns.digitale-gesellschaft.ch/dns-query"
      ];
      bootstrap_dns = [
        "5.9.164.112" # Digitalcourage
        "5.1.66.255" # FFMUC
        "1.1.1.1"
        "1.0.0.1"
        "9.9.9.9"
      ];
      fallback_dns = [
        "tls://anycast.uncensoreddns.org"
        "tls://unfiltered.adguard-dns.com"
        "https://unfiltered.adguard-dns.com/dns-query"
        "tls://dns.njal.la"
      ];
      upstream_mode = "fastest_addr";
      use_http3_upstreams = true;
      use_dns64 = true;
      cache_enabled = true;
      cache_optimistic = true;
      tls = {
        enabled = false;
        server_name = "frei.kauderwels.ch";
      };
      dhcp.enabled = false;
    };
  };

  networking.firewall = {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [ 53 ];
  };
}
