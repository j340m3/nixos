# dendritic: aggregate home aspect for jeromeb (ADR 0014). One source shared
# by the standalone homeConfigurations.jeromeb (modules/nix/home-configurations.nix)
# and per-host wiring (rex/lenny home-manager.users.jeromeb).
_: {
  flake.modules.homeManager.jeromeb =
    {
      pkgs,
      inputs,
      lib,
      osConfig ? { },
      ...
    }:
    let
      # Storage-tier kit (improvement session 2026-11-12): small hosts get the
      # CLI-only kit, medium adds messaging, large the full desktop kit. The
      # tier is a host fact (osConfig.storage.tier, roster in
      # modules/global/_constants.nix). Standalone homeConfigurations have no
      # osConfig and keep the full kit. donquezz is deliberately package-free
      # (unprivileged admin alias) and does not import this aspect.
      tier = osConfig.storage.tier or "large";
      cli = with pkgs; [
        btop
        git
        vulnix
        sops
        nh
        nix-du
        pinentry-curses
        wezterm
      ];
      messaging = with pkgs; [
        signal-desktop
        telegram-desktop
      ];
      desktop = with pkgs; [
        spotify
        element-desktop
        radicle-desktop
        radicle-node
      ];
    in
    {
      imports = [
        inputs.stylix.homeModules.stylix
        inputs.sops-nix.homeManagerModules.sops
        inputs.self.modules.homeManager.style
        inputs.self.modules.homeManager.vscode
        inputs.self.modules.homeManager.browser
        inputs.self.modules.homeManager.accounts
        inputs.self.modules.homeManager.xfce
      ];
      home.username = "jeromeb";
      # radicle-desktop pulls in radicle-node, which nixpkgs marks insecure
      nixpkgs.config.permittedInsecurePackages = [
        "radicle-node-1.10.3"
      ];
      home.homeDirectory = "/home/jeromeb";
      home.stateVersion = "25.11"; # Comment out for error with "latest" version
      #stylix.homeManagerIntegration.autoImport = false;
      #stylix.homeManagerIntegration.followSystem = false;
      programs.home-manager.enable = true;

      home.packages =
        cli
        ++ lib.optionals (tier == "medium" || tier == "large") messaging
        ++ lib.optionals (tier == "large") desktop;

      programs.rbw = {
        enable = true;
      };

      home.sessionVariables = {
        # Braced ${XDG_RUNTIME_DIR}: pam_env rejects the unbraced $VAR form and
        # silently ignores the variable.
        SSH_AUTH_SOCK = "\${XDG_RUNTIME_DIR}/rbw/ssh-agent-socket";
      };

      nixpkgs.config.allowUnfreePredicate =
        pkg:
        builtins.elem (lib.getName pkg) [
          "spotify"
          "apple_cursor"
        ];

    };
}
