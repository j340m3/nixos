{ config, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ./hardening.nix
  ];
  swapDevices = [ { device = "/swapfile"; size = 1024; } ];
  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  
  environment.systemPackages = with pkgs; [
    #bc
    #ipcalc
    #curl
    #procps
    lynis
    git
  ];

  networking.hostName = "nixos-gb";
  networking.domain = "";
  services.fail2ban.enable = true;
  services.openssh = {
    ports = [22 80];
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
    settings.PermitRootLogin = "no";
    settings.AllowGroups = [ "wheel" ];
    settings.AllowTcpForwarding = "no";
    settings.ClientAliveCountMax = 2;
    settings.MaxAuthTries = 3;
    settings.MaxSessions = 2;
    settings.TCPKeepAlive = "no";
    settings.AllowAgentForwarding = "no";
  };
  #services.prometheus.enable = true;
  #services.icingaweb2.enable = true;
  users.mutableUsers = false;
  users.users.root.openssh.authorizedKeys.keys = [''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKv3fhY8KfwN4GFxXpbWLCfNl4ZP+v+C59CIxXhj0SyB jerome@DESKTOP-B7K2FBB'' ];
  users.users.donquezz = {
    isNormalUser  = true;
    home  = "/home/donquezz";
    description  = "Jerome Bergmann";
    extraGroups  = [ "wheel" "networkmanager" ];
    hashedPassword = "$y$j9T$xI3Gvnwn4Q900uL0HQZHp/$fl5oFfnZWZWBz.6gPxvciND13komHHAXDqq6Yfpjn17";
    openssh.authorizedKeys.keys = [
	''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKv3fhY8KfwN4GFxXpbWLCfNl4ZP+v+C59CIxXhj0SyB jerome@DESKTOP-B7K2FBB'' 
        ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICBx/L/AY2505t1Sj1yyugnK6Cf2QuIECx8kXxyoks3f jeromeb@nixos''
    ];
  };
  #users.users.monitoring = {
  #  isSystemUser = true;
  #  createHome = false;
  #  packages = with pkgs; [
  #    bc
  #    ipcalc
  #    curl
  #  ];
  #  group = "monitoring";
  #};
  #users.groups.monitoring = {};
  
  system.stateVersion = "23.11";

  nix.settings.auto-optimise-store = true;
  #system.autoUpgrade.enable  = true;
  #system.autoUpgrade.allowReboot  = true;
  #system.autoUpgrade.dates = "daily";  

  system.autoUpgrade = {
    enable = true;
    #flake = "/etc/nixos#nixos-gb";
    flake = "github:j340m3/nixos#nixos-gb";
    flags = [ 
      "--update-input" "nixpkgs" 
      "--no-write-lock-file"
    ];
    allowReboot  = true;
    dates = "hourly";
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  systemd.services.monitoring = {
    path = with pkgs; [
      bc
      ipcalc
      curl
      procps
      gawk
      coreutils
      iproute2
    ];
    script = ''
      ${pkgs.bash}/bin/bash /root/system-monitoring.sh --NAME "NixOS-GB" --LA1 --LA5 --LA15 --CPU 80 --RAM 80 --DISK 80 --SSH-LOGIN --SFTP-MONITOR --REBOOT 2>&1 >> /var/log/monitoring/monitoring.log
    '';
    wantedBy = [ "multi-user.target" ];
  };

  security.sudo.wheelNeedsPassword = true;
}
