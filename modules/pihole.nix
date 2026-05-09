{ ... }:
{
  /*
    services.adguardhome = {
      enable = true;
      settings = {
        dns = {
          bind_hosts = [
            "0.0.0.0"
          ];
          anonymize_client_ip = true;
          #filtering_enabled = true;
          upstream_dns = [
            "tls://dns3.digitalcourage.de"
            "tls://dot.ffmuc.net"
            "tls://dns.digitale-gesellschaft.ch"
            "https://doh.ffmuc.net/dns-query"
            "https://dns.digitale-gesellschaft.ch/dns-query"
          ];
          bootstrap_dns = [
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
          upstream_mode = "parallel";
          use_http3_upstreams = true;
          use_dns64 = true;
          cache_enabled = true;
          cache_optimistic = true;
          cache_size = 1048576;
        };

        tls = {
          enabled = false;
          server_name = "frei.kauderwels.ch";
        };
        querylog = {
          file_enabled = false;
          interval = "48h";
        };
        dhcp.enabled = false;
        filters = [
          {
            enabled = true;
            url = "https://raw.githubusercontent.com/j340m3/anti-parental-lists/refs/heads/main/family-link.txt";
            id = 1;
          }
        ];
        log = {
          verbose = true;
          compress = true;
          file = "/tmp/ahglog.txt";
        };
      };
    };
  */

  networking.firewall = {
    allowedTCPPorts = [
      53
      853
    ];
    allowedUDPPorts = [ 53 ];
  };

  services.dnsdist = {
    enable = true;
    extraConfig = ''
      -- addLocal("0.0.0.0:53")
      addLocal("[::]:53")
      addTLSLocal('[::]', '/etc/ssl/certs/kauderwels.ch_ssl_certificate_chain.cer', '/etc/ssl/certs/_.kauderwels.ch_private_key.key')
      addTLSLocal('0.0.0.0', '/etc/ssl/certs/kauderwels.ch_ssl_certificate_chain.cer', '/etc/ssl/certs/_.kauderwels.ch_private_key.key')
      newServer({address="[2a01:4f8:251:554::2]:853", tls="openssl", subjectName="dns3.digitalcourage.de", validateCertificates=true})
      -- FFMUC
      newServer("5.1.66.255")
      setACL({'0.0.0.0/0', '[::]/0'})
      pc = newPacketCache(100000,{keepStaleData=true, shuffle=true})
      getPool(""):setCache(pc)
      addAction(RegexRule("dns\\.google"), SpoofAction({"194.164.54.40","2a01:239:27f:fd00::1"}))
      addAction(RegexRule("history\\.google\\.com"), SpoofAction({"0.0.0.0", "[::]"}))
      addAction(RegexRule("kidsmanagement-pa\\.googleapis\\.com"), SpoofAction({"0.0.0.0", "[::]"}))
      addAction(RegexRule("kidsmanagement-pa\\.clients6\\.googleapis\\.com"), SpoofAction({"0.0.0.0", "[::]"}))
      addAction(RegexRule("families\\.google\\.com"), SpoofAction({"0.0.0.0", "[::]"}))
      addAction(RegexRule("parenttools\\.google\\.com"), SpoofAction({"0.0.0.0", "[::]"}))
      addAction(RegexRule("mtalk-europe\\.google\\.com"), SpoofAction({"0.0.0.0", "[::]"}))
    '';
  };
}
