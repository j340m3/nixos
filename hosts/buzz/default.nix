# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, modulesPath, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      #inputs.sops-nix.nixosModules.sops
      #inputs.disko.nixosModules.disko
      #inputs.impermanence.nixosModules.impermanence
      #inputs.peerix.nixosModules.peerix
      #../bootstrap --> TODO: Check buzz if hes doing alright
      (modulesPath + "/profiles/minimal.nix")
      (modulesPath + "/profiles/headless.nix")
      ../../modules/hardening.nix
      ../../modules/swap.nix
      ../../modules/common 
      ../../users/donquezz.nix
      ../../modules/logging.nix
      ../../modules/persistence.nix
      ../../modules/zabbix.nix
    ];

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  # boot.loader.grub.efiSupport = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # Define on which hard drive you want to install Grub.
  # boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only
  security.sudo.extraConfig = ''
    # rollback results in sudo lectures after each reboot
    Defaults lecture = never
  '';
  networking.hostName = "buzz"; # Define your hostname.
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
  
  environment.systemPackages = with pkgs; [
    nebula
  ];
  services.nebula.networks.mesh = {
    enable = true;
    isLighthouse = true;
    isRelay = true;
    cert = config.sops.secrets."nebula/self_crt".path; #"/run/secrets/nebula/self.crt";
    key = config.sops.secrets."nebula/self_key".path; #"/run/secrets/nebula/self.key";
    ca = config.sops.secrets."nebula/ca_crt".path; #"/run/secrets/nebula/ca.crt";
    staticHostMap = {
        "10.0.0.1" = [
                "194.164.125.154:4242"
                ];
        };
    settings = {
      lighthouse = {
        serve_dns = true;
        dns = {
          host = "0.0.0.0";
          port = 53;
        };
      };
      cipher = "aes";
      punchy = {
        punch = true;
        reload = true;
      };
    };
    firewall.outbound = [
      {
      host = "any";
      port = "any";
      proto = "any";
      }
    ];
    firewall.inbound = [
    {
      host = "any";
      port = "22";
      proto = "tcp";
    }
    {
      host = "any";
      port = "any";
      proto = "icmp";
    }
    {
      host = "any";
      port = "53";
      proto = "udp";
    }
    {
      host = "any";
      port = "10050";
      proto = "any";
    }
    {
      host = "any";
      port = "42069";
      proto = "tcp";
    }
    ];
  };
  
  systemd.services."nebula@mesh".serviceConfig = {
        CapabilityBoundingSet = lib.mkForce "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
        AmbientCapabilities = lib.mkForce "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
  };
  # allow nebula to claim port 53 from systemd-resolved
  services.resolved.extraConfig = ''
    DNSStubListener=no
  '';
  # open the systems firewall for DNS on the nebula interface and public interfaces
  networking.firewall.interfaces."nebula.mesh".allowedUDPPorts = [ 53 ];
  networking.firewall.allowedUDPPorts = [ 53 ];

  sops.secrets."nebula/ca_crt" = {
    restartUnits = ["nebula@mesh.service"];
    owner = "nebula-mesh";
    group = "nebula-mesh";
    path = "/nix/persist/etc/nebula/ca.crt";
  };
  sops.secrets."nebula/self_crt" = {
    sopsFile = ../../secrets/${config.networking.hostName}/secrets.yaml;
    restartUnits = ["nebula@mesh.service"];
    owner = "nebula-mesh";
    group = "nebula-mesh";
    path = "/nix/persist/etc/nebula/self.crt";
  };
  sops.secrets."nebula/self_key" = {
    sopsFile = ../../secrets/${config.networking.hostName}/secrets.yaml;
    restartUnits = ["nebula@mesh.service"];
    owner = "nebula-mesh";
    group = "nebula-mesh";
    path = "/nix/persist/etc/nebula/self.key";
  };
}