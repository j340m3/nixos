# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./_hardware-configuration.nix
    ../../../modules/_common
    ../../../users/donquezz.nix
    ../../../modules/_loghost.nix
    ../../../modules/_borg-server.nix
    #../../../modules/_peerix.nix
    ../../../desktop-environments/kde.nix
    #../../../desktop-environments/mate.nix
    ../../../modules/_wifi.nix
    ./_immich.nix
    ./_paperless.nix
    ./_xrdp.nix
    ./_nas.nix
    ./_nofile.nix
    ./_firefox.nix
    ./_power.nix
    ./_zabbix.nix
    ./_home-assistant.nix
    ../../../modules/_harmonia.nix
    ../../../modules/_nfs-fee.nix
    ../../../modules/_nebula.nix
    #../../../modules/_technitium.nix
    ../../../modules/_prometheus.nix
    ../../../modules/_grafana.nix
    ../../../modules/_fritz-exporter.nix
    # ./_firefox.nix
    #(fetchTarball "https://github.com/nix-community/nixos-vscode-server/tarball/master")
    #<home-manager/nixos>
    inputs.chaotic.nixosModules.default
  ];

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;

  # 24/7 homeserver: self-repair like the headless hosts. The
  # graphical/interests-of-saved-work exclusion is relaxed here
  # because nobody sits at this display — it is reached via xrdp only.
  upgradeHealth.enable = true;

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_cachyos-lto;
  services.scx.enable = true;

  networking.hostName = "woody"; # Define your hostname.
  #networking.domain = "fritz.box";
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Enable network manager applet
  programs.nm-applet.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };

  # Enable the X11 windowing system.
  #services.xserver.enable = true;

  # Enable the MATE Desktop Environment.
  #services.xserver.displayManager.lightdm.enable = true;
  #services.xserver.desktopManager.mate.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "de";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "de";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    # media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;
  nix.settings.max-jobs = 6;
  nix.settings.cores = 6;
  nix.distributedBuilds = lib.mkForce false;
  nix.settings.trusted-users = [ "jeromeb" ];

  users.groups.plugdev = { };
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.jeromeb = {
    isNormalUser = true;
    description = "Jerome Bergmann";
    extraGroups = [
      "networkmanager"
      "wheel"
      "plugdev"
    ];
    packages = with pkgs; [
      #goose-cli
      htop
      rbw
      pinentry-curses
      # home-manager
      github-desktop
      (vscode-with-extensions.override {
        vscode = vscodium;
        vscodeExtensions = with vscode-extensions; [
          bbenoist.nix
        ];
      })
      #  thunderbird
    ];
  };
  #users.users.eve.isNormalUser = true;
  /*
    home-manager.users.jeromeb = { pkgs, ... }: {
      home.packages = [ pkgs.atool pkgs.httpie ];
      programs.bash.enable = true;

      # The state version is required and should stay at the version you
      # originally installed.
      home.stateVersion = "24.11";
      programs.home-manager.enable = true;
      programs.neovim.plugins = [ pkgs.vimPlugins.parinfer-rust ];

    };
    home-manager.backupFileExtension = "backup.hm";
  */
  environment.sessionVariables = {
    SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/rbw/ssh-agent-socket";
  };
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    intel-undervolt
    undervolt
    s-tui
    stress
    btop
    novnc
    cifs-utils
    libfido2
    pam_u2f
    vulnix
    git
    elmPackages.elm
    #elmPackages.elm-analyse
    #elmPackages.elm-coverage
    elmPackages.elm-format
    elmPackages.elm-json
    elmPackages.elm-review
    elmPackages.elm-upgrade
    mate.caja-with-extensions
    rclone
    #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    #  wget
  ];
  services.yubikey-agent.enable = true;
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
  networking.firewall.logRefusedConnections = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

  system.autoUpgrade = {
    #enable = true;
    # allowReboot  = true;
    dates = "hourly";
  };
  #useComin = true;

  nix.gc = {
    automatic = true;
    dates = "hourly";
    options = "--delete-older-than 7d";
  };

  # Please do upgrades in Background
  /*
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
  */

  #  systemd.services.monitoring = {
  #    path = with pkgs; [
  #      bc
  #      ipcalc
  #      curl
  #      procps
  #      gawk
  #      coreutils
  #      iproute2
  #    ];
  #    script = ''
  #      ${pkgs.bash}/bin/bash /root/system-monitoring.sh --NAME "NixOS-GB" --LA1 --LA5 --LA15 --CPU 80 --RAM 80 --DISK 80 --SSH-LOGIN --SFTP-MONITOR --REBOOT 2>&1 >> /var/log/monitoring/monitoring.log
  #    '';
  #    wantedBy = [ "multi-user.target" ];
  #  };

  # A glibc bump changes the collation version, and postgres then warns on
  # every connection. Reindex each connectable database once, then record the
  # new version. Best-effort: never keep postgres from starting.
  systemd.services.postgresql.postStart = lib.mkAfter ''
    psql=${config.services.postgresql.package}/bin/psql
    "$psql" -tAc "select datname from pg_database where datallowconn and datcollversion is not null and datcollversion <> '${pkgs.glibc.version}'" |
      while IFS= read -r db; do
        [ -n "$db" ] || continue
        if "$psql" -d "$db" -c "REINDEX DATABASE \"$db\";"; then
          "$psql" -d postgres -c "ALTER DATABASE \"$db\" REFRESH COLLATION VERSION;" || true
        fi
      done
    true
  '';

  #services.vscode-server.enable = true;
  services.udev.packages = [ pkgs.libfido2 ];
  #services.udev.packages = [ pkgs.yubikey-personalization ];

  #services.udev.extraRules = ''
  #  # this udev file should be used with udev 188 and newer
  #  ACTION!="add|change", GOTO="u2f_end"
  #
  #  # PID for FIDO U2F
  #  KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="096e", ATTRS{idProduct}=="0854", TAG+="uaccess"
  #
  #  LABEL="u2f_end"
  #'';

  #  programs.gnupg.agent = {
  #    enable = true;
  #    enableSSHSupport = true;
  #  };
}
