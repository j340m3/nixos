{
  services.xrdp.enable = true;
  #services.xrdp.defaultWindowManager = "mate-session";
  services.xrdp.defaultWindowManager = "startplasma-x11";
  services.xrdp.openFirewall = true;
  #services.xrdp.extraConfDirCommands = "substituteInPlace $out/sesman.ini --replace-fail '#SessionSockdirGroup=xrdp' 'SessionSockdirGroup=xrdp'";
}
