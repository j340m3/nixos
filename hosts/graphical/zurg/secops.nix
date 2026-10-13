{pkgs,...}:{
  environment.systemPackages = with pkgs; [
    wireshark
    burpsuite
    metasploit
    wpscan
    nikto
    sqlmap
    starkiller
    gophish
  ];
}
