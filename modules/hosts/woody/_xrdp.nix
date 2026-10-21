{
  services.xrdp.enable = true;
  #services.xrdp.defaultWindowManager = "mate-session";
  services.xrdp.defaultWindowManager = "startplasma-x11";
  services.xrdp.openFirewall = true;
  # xrdp logs every RDP callback at INFO; that produced ~1GB/week of
  # pointer addresses on the loghost.  WARNING is enough to troubleshoot.
  services.xrdp.extraConfDirCommands = ''
    substituteInPlace $out/sesman.ini --replace-fail 'LogLevel=INFO' 'LogLevel=WARNING'
    substituteInPlace $out/xrdp.ini --replace-fail 'LogLevel=INFO' 'LogLevel=WARNING'
  '';
}
