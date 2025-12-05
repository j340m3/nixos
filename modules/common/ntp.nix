{...}:{
  services.chrony = {
    enable = true;
    enableNTS = true;
    servers = [
      "time.cloudflare.com"
      "ntppool1.time.nl"
      "nts.netnod.se"
      "ptbtime1.ptb.de"
      "time.dfm.dk"
      "time.cifelli.xyz"
      "ptbtime1.ptb.de"
      "ptbtime2.ptb.de"
      "ptbtime3.ptb.de"
      "ptbtime4.ptb.de"
      "ntp.zeitgitter.net"
      "ntp.trifence.ch"
    ];
  };
}
