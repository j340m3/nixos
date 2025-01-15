{ modulesPath, config, pkgs, lib, self, home-manager, ... }: {
  imports = [
     ./hardware-configuration.nix
     (modulesPath + "/profiles/minimal.nix")
     (modulesPath + "/profiles/headless.nix")
    ./hardening.nix
    #./vaultwarden.nix
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
    chkrootkit
    nix-tree
  ];

  networking.hostName = "nixos-gb";
  networking.domain = "";
  services.fail2ban.enable = true;
  services.openssh = {
    ports = [22 42069];
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
  users.users.root.packages = with pkgs; [
    openssl
  ];
  users.users.donquezz = {
    isNormalUser  = true;
    home  = "/home/donquezz";
    description  = "Jerome Bergmann";
    extraGroups  = [ "wheel" "networkmanager" ];
    hashedPassword = "$y$j9T$xI3Gvnwn4Q900uL0HQZHp/$fl5oFfnZWZWBz.6gPxvciND13komHHAXDqq6Yfpjn17";
    openssh.authorizedKeys.keys = [
	''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKv3fhY8KfwN4GFxXpbWLCfNl4ZP+v+C59CIxXhj0SyB jerome@DESKTOP-B7K2FBB'' 
        ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICBx/L/AY2505t1Sj1yyugnK6Cf2QuIECx8kXxyoks3f jeromeb@nixos''
        ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHVNoVYUWvAghff/jL6lHW80p73L/eGWDMUDeJ4TpZeO jerome@DESKTOP-4SBFVCM''
        ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG8Wfyik+a9oL7hPG3T72maa14lYmI+k6fzqZP/t59MK Generated By Termius''
    ];
  };
  home-manager.users.donquezz = { pkgs, ... }: {
    home.packages = [ pkgs.atool pkgs.httpie ];
    programs.zsh.enable = true;

    # The state version is required and should stay at the version you
    # originally installed.
    home.stateVersion = "24.11";
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

  #nix.settings.auto-optimise-store = true;
  #system.autoUpgrade.enable  = true;
  #system.autoUpgrade.allowReboot  = true;
  #system.autoUpgrade.dates = "daily";  

  system.autoUpgrade = {
    enable = true;
    #flake = "/etc/nixos#nixos-gb";
    flake = "github:j340m3/nixos#nixos-gb";
    #flake = self;
    flags = [ 
    #  "--update-input" "nixpkgs" 
      "--no-write-lock-file"
    ];
    allowReboot  = true;
    dates = "hourly";
  };

  nix.gc = {
    automatic = true;
    dates = "hourly";
    options = "--delete-older-than 1d";
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

  programs.mosh.enable = true;
  networking.firewall.allowedTCPPorts = [ 443 ];
  networking.firewall.allowedUDPPortRanges = [
    { from = 60000; to = 61000; }
  ];
services.nginx = {
  enable = true;
  virtualHosts.localhost = {
    forceSSL = true;
    listen = [{port = 442;  addr="0.0.0.0"; ssl=true;}];
    #onlySSL = true;
    #listen = [{
    #addr = "localhost";
    #port = 443;
    #ssl = true;
    #}];
    locations."/" = {
      return = "200 '<html><body>It works</body></html>'";
      extraConfig = ''
        default_type text/html;
      '';
    };
    sslCertificate = "/etc/nixos-selfsigned.crt";
    sslCertificateKey = "/etc/nixos-selfsigned.key";
  };
};
  
  services.sslh.enable = true;
  services.sslh.settings.transparent = true;
  services.sslh.method = "fork";
  services.sslh.settings.protocols = [
	  {
	    host = "localhost";
	    name = "ssh";
	    port = "22";
	    service = "ssh";
	  }
	  {
	    host = "localhost";
	    name = "http";
	    port = "80";
	  }
	  {
	    host = "localhost";
	    name = "tls";
	    port = "442";
	  }
  ];
  services.logrotate.enable = true;
  services.logrotate.checkConfig = false;

  # Please do upgrades in Background
  nix = {
    package = pkgs.nix;
    settings.experimental-features = [ "nix-command" "flakes" ];
    settings.auto-optimise-store = true;
    settings.max-jobs = 1;
    settings.cores = 1;
    daemonIOSchedClass = lib.mkDefault "idle";
    daemonCPUSchedPolicy = lib.mkDefault "idle";
  };
  systemd.services.nix-daemon.serviceConfig.Slice = "-.slice";
  # always use the daemon, even executed  with root
  environment.variables.NIX_REMOTE = "daemon";
  systemd.services.nix-daemon.serviceConfig = {
    MemoryHigh = "800M";
    MemoryMax = "1G";
  };
  
  
}
