# Source: https://github.com/busyammonia/my-flake/blob/9b0140c08895b2af2ea5d48e83344a94710c97cd/hosts/common/optional/time/chrony.nix
{ pkgs, config, lib, ... }: {
  services = {
    chrony = let
      # A set of servers that support NTS, preventing MITM attacks.
      # https://github.com/jauderho/nts-servers/blob/9eab8051749ede4c1014e0c23840f3316e874027/chrony.conf
      ntsServers = [
        # Cloudflare (Anycast)
        "time.cloudflare.com "

        # NTP.br (Brazil)
        "a.st1.ntp.br"
        "b.st1.ntp.br"
        "c.st1.ntp.br"
        "d.st1.ntp.br"
        "gps.ntp.br"

        # Brazil
        "time.bolha.one"

        # Friedrich-Alexander-Universität / FAU (Germany)
        "ntp3.fau.de"
        "ntp3.ipv6.fau.de"

        # Physikalisch-Technische Bundesanstalt / PTB (Germany)
        "ptbtime1.ptb.de"
        "ptbtime2.ptb.de"
        "ptbtime3.ptb.de"
        "ptbtime4.ptb.de"

        # Germany
        "www.jabber-germany.de"
        "www.masters-of-cloud.de"
        "ntp-by.dynu.net"
        "nts.ntstime.de"

        # TimeNL (Netherlands)
        "ntppool1.time.nl"
        "ntppool2.time.nl"

        # Singapore
        "ntpmon.dcs1.biz"

        # Netnod (Sweden)
        "nts.netnod.se"
        "gbg1.nts.netnod.se"
        "gbg2.nts.netnod.se"
        "lul1.nts.netnod.se"
        "lul2.nts.netnod.se"
        "mmo1.nts.netnod.se"
        "mmo2.nts.netnod.se"
        "sth1.nts.netnod.se"
        "sth2.nts.netnod.se"
        "svl1.nts.netnod.se"
        "svl2.nts.netnod.se"

        # Switzerland
        "ntp.3eck.net"
        "ntp.trifence.ch"
        "ntp.zeitgitter.net"
        "time.signorini.ch"

        # System76 (US / France / Brazil)
        "virginia.time.system76.com"
        "ohio.time.system76.com"
        "oregon.time.system76.com"
        "paris.time.system76.com"
        "brazil.time.system76.com"

        # US
        "stratum1.time.cifelli.xyz"
        "time.cifelli.xyz"
        "time.txryan.com"
      ];
    in {
      enable = true;
      enableNTS = true;
      servers = ntsServers;
      enableRTCTrimming = true;
      enableMemoryLocking = true;
      directory = "/var/lib/chrony";
      initstepslew = {
        enabled = true;
        threshold = 10;
      };
      extraConfig = ''
        # Only update the local clock if at least four sources are considered
        # good.
        minsources 4

        # Where possible, tell the network interface's hardware to timestamp
        # exactly when packets are received/sent to increase accuracy.
        hwtimestamp *
      '';
    };
  };
}
