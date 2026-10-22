# Host aspect (ADR 0014): flake.modules.nixos.jessie is assembled by lib.mkNixos
# (modules/nix/lib.nix); the flake-parts.nix one-liner next to this file
# declares the host into the flake. inputs arrive via the transitional
# specialArgs in the factory, so the head args stay verbatim.
{ inputs, lib, ... }:

{
  flake.modules.nixos.jessie =
    {
      config,
      lib,
      pkgs,
      modulesPath,
      ...
    }:
    {
      imports = [
        # Include the results of the hardware scan.
        ./_hardware-configuration.nix
        #../bootstrap
        (modulesPath + "/profiles/minimal.nix")
        (modulesPath + "/profiles/headless.nix")
        ../../../modules/_hardening.nix
        #../../modules/_swap.nix
        inputs.self.modules.nixos.system-default
        ../../../users/donquezz.nix
        inputs.self.modules.nixos.logging
        inputs.self.modules.nixos.persistence
        inputs.self.modules.nixos.nebula
        #../../../modules/_zabbix.nix
        inputs.self.modules.nixos.minecraft-bedrock
        ../../../modules/_wireguard.nix
        inputs.self.modules.nixos.minecraft-java
        #../../../modules/_matrix3.nix
        ../../../modules/_acme.nix
        inputs.self.modules.nixos.radicle-seed
      ];

      #system.autoUpgrade.dates = lib.mkForce "daily";
      #nix.gc.dates = lib.mkForce "daily";

      # Use the GRUB 2 boot loader.
      boot.loader.grub.enable = true;
      # boot.loader.grub.efiSupport = true;
      # boot.loader.grub.efiInstallAsRemovable = true;
      # boot.loader.efi.efiSysMountPoint = "/boot/efi";
      # Define on which hard drive you want to install Grub.ü
      # boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only
      security.sudo.extraConfig = ''
        # rollback results in sudo lectures after each reboot
        Defaults lecture = never
      '';
      networking.hostName = "jessie"; # Define your hostname.
      zramSwap.enable = false;
      # 1-core/1.8GB host shared with the minecraft container: nix builds (remote
      # ones arrive via the remotebuild SSH session) run at low priority and one
      # at a time, so bedrock_server wins CPU under contention.
      # Hard CPUQuota would idle the core whenever the game is quiet — avoided.
      nix = {
        daemonCPUSchedPolicy = "idle";
        settings.max-jobs = lib.mkForce 1;
      };
      security.pam.loginLimits = [
        {
          domain = "remotebuild";
          item = "nice";
          value = 15;
        }
      ];
      # autoUpgrade runs as root and bypasses nix-daemon, so nice it separately.
      systemd.services.nixos-upgrade.serviceConfig.Nice = 15;
      # Pick only one of the below networking options.
      # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
      # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

      # Set your time zone.
      # time.timeZone = "Europe/Amsterdam";

      # Configure network proxy if necessary
      # networking.proxy.default = "http://user:password@proxy:port/";
      # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

      # Select internationalisation properties.
      # i18n.defaultLocale = "en_US.UTF-8";
      # console = {
      #   font = "Lat2-Terminus16";
      #   keyMap = "us";
      #   useXkbConfig = true; # use xkb.options in tty.
      # };

      # Enable the X11 windowing system.
      # services.xserver.enable = true;

      # Configure keymap in X11
      # services.xserver.xkb.layout = "us";
      # services.xserver.xkb.options = "eurosign:e,caps:escape";

      # Enable CUPS to print documents.
      # services.printing.enable = true;

      # Enable sound.
      # services.pulseaudio.enable = true;
      # OR
      # services.pipewire = {
      #   enable = true;
      #   pulse.enable = true;
      # };

      # Enable touchpad support (enabled default in most desktopManager).
      # services.libinput.enable = true;

      # Define a user account. Don't forget to set a password with ‘passwd’.
      # users.users.alice = {
      #   isNormalUser = true;
      #   extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
      #   packages = with pkgs; [
      #     tree
      #   ];
      # };

      # programs.firefox.enable = true;

      # List packages installed in system profile. To search, run:
      # $ nix search wget
      # environment.systemPackages = with pkgs; [
      #   vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
      #   wget
      # ];

      # Some programs need SUID wrappers, can be configured further or are
      # started in user sessions.
      # programs.mtr.enable = true;
      # programs.gnupg.agent = {
      #   enable = true;
      #   enableSSHSupport = true;
      # };

      # List services that you want to enable:

      # Enable the OpenSSH daemon.
      # services.openssh.enable = true;

      # Open ports in the firewall.
      # networking.firewall.allowedTCPPorts = [ ... ];
      # networking.firewall.allowedUDPPorts = [ ... ];
      # Or disable the firewall altogether.
      networking.firewall.enable = true;

      # Copy the NixOS configuration file and link it from the resulting system
      # (/run/current-system/configuration.nix). This is useful in case you
      # accidentally delete configuration.nix.
      # system.copySystemConfiguration = true;

      # This option defines the first version of NixOS you have installed on this particular machine,
      # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
      #
      # Most users should NEVER change this value after the initial install, for any reason,
      # even if you've upgraded your system to a new NixOS release.
      #
      # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
      # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
      # to actually do that.
      #
      # This value being lower than the current NixOS release does NOT mean your system is
      # out of date, out of support, or vulnerable.
      #
      # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
      # and migrated your data accordingly.
      #
      # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
      system.stateVersion = "25.05"; # Did you read the comment?

      # rolls this host back to the previous generation and reboots it when systemd
      # reports a failed unit one settle delay after switch-to-configuration
      upgradeHealth.enable = true;
    };
}
