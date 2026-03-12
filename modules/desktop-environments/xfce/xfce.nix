{
  flake.modules.nixos.xfce =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      environment = {
        systemPackages = with pkgs; [
          blueman
          chromium
          deja-dup
          drawing
          evince
          firefox
          foliate
          font-manager
          gimp-with-plugins
          file-roller
          gnome-disk-utility
          inkscape-with-extensions
          libqalculate
          orca
          pavucontrol
          qalculate-gtk
          thunderbird
          wmctrl
          xclip
          xcolor
          xcolor
          xdo
          xdotool
          xfce.catfish
          xfce.gigolo
          xfce.orage
          xfce.xfburn
          xfce.xfce4-appfinder
          xfce.xfce4-clipman-plugin
          xfce.xfce4-cpugraph-plugin
          xfce.xfce4-dict
          xfce.xfce4-fsguard-plugin
          xfce.xfce4-genmon-plugin
          xfce.xfce4-netload-plugin
          xfce.xfce4-panel
          xfce.xfce4-pulseaudio-plugin
          xfce.xfce4-systemload-plugin
          xfce.xfce4-weather-plugin
          xfce.xfce4-whiskermenu-plugin
          xfce.xfce4-xkb-plugin
          xfce.xfdashboard
          xorg.xev
          xsel
          xtitle
          #xwinmosaic
        ];
      };

      programs = {
        dconf.enable = true;
        gnupg.agent = {
          enable = true;
          enableSSHSupport = true;
        };
        thunar = {
          enable = true;
          plugins = with pkgs.xfce; [
            thunar-archive-plugin
            thunar-media-tags-plugin
            thunar-volman
          ];
        };
      };

      security.pam.services.gdm.enableGnomeKeyring = true;

      services = {
        blueman.enable = true;
        gnome.gnome-keyring.enable = true;
        pipewire = {
          enable = true;
          alsa = {
            enable = true;
            support32Bit = true;
          };
          pulse.enable = true;
        };
        xserver = {
          enable = true;
          excludePackages = with pkgs; [
            xterm
          ];
          displayManager = {
            lightdm = {
              enable = true;
              greeters.slick = {
                enable = true;
              };
            };
          };
          desktopManager.xfce.enable = true;
        };
      };

      # xfce-terminal use system font
      programs.xfconf.enable = true; # https://github.com/NixOS/nixpkgs/issues/256428

    };

  flake.modules.homeManager.xfce =
    {
      config,
      pkgs,
      lib,
      ...
    }:

    {
      gtk = {
        enable = true;
        theme = {
          package = lib.mkForce pkgs.whitesur-gtk-theme;
          name = lib.mkForce "WhiteSur-Dark";
        };
        # iconTheme = {
        #   package = pkgs.whitesur-icon-theme.override {
        #     alternativeIcons = true;
        #     boldPanelIcons = true;
        #   };
        #   name = "WhiteSur";
        # };
        gtk3.extraConfig = {
          Settings = ''
            gtk-application-prefer-dark-theme=1
          '';
        };
        gtk4.extraConfig = {
          Settings = ''
            gtk-application-prefer-dark-theme=1
          '';
        };
      };

      home.sessionVariables.GTK_THEME = "WhiteSur-Dark";

      stylix.targets.xfce.enable = true;

      programs.gpg.enable = true;

      services.gpg-agent.enable = true;
    };
}
