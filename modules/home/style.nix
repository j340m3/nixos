# dendritic: home-manager class aspect "style" (ADR 0014). Consumed via
# inputs.self.modules.homeManager.style by the standalone homeConfigurations
# (modules/nix/home-configurations.nix) and the per-host wiring (rex/lenny).
_: {
  flake.modules.homeManager.style =
    {
      pkgs,
      inputs,
      lib,
      ...
    }:
    {
      imports = [

      ];

      stylix.autoEnable = true;
      stylix.enable = true;

      stylix.base16Scheme = "${inputs.tinted-schemes}/base16/catppuccin-frappe.yaml";
      #stylix.polarity = "light";
      stylix.fonts = {
        monospace = {
          package = pkgs.nerd-fonts.victor-mono;
          name = "VictorMono Nerd Font Mono";
        };
        # sansSerif = {
        #   package = inputs.apple-fonts.packages.${pkgs.system}.sf-pro-nerd;
        #   name = "SFProDisplay Nerd Font";
        # };
        # serif = {
        #   package = inputs.apple-fonts.packages.${pkgs.system}.sf-pro-nerd;
        #   name = "SFProDisplay Nerd Font";
        # };
        emoji = {
          package = pkgs.noto-fonts-color-emoji;
          name = "Noto Color Emoji";
        };
      };
      stylix.cursor = {
        name = "macOS";
        package = pkgs.apple-cursor;
        size = 36;
      };
      stylix.icons = {
        enable = true;
        package = pkgs.whitesur-icon-theme;
        dark = "WhiteSur-dark";
        light = "WhiteSur-light";
      };

      stylix.targets.firefox.profileNames = [ "personal" ];
    };
}
