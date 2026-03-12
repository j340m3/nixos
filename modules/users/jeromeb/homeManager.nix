{
  inputs,
  lib,
  ...
}:
let
  username = "jeromeb";
in
{
  flake.modules.homeManager."${username}" =
    { pkgs, ... }:
    {
      imports = with inputs.self.modules.homeManager; [
        system-default
        # messaging
      ];
      home.username = "${username}";

      home.packages = with pkgs; [
        btop
        git
        wezterm
        spotify
        signal-desktop
        telegram-desktop
        element-desktop
        radicle-desktop
        radicle-node
        sops
        bitwarden-desktop
      ];
    };
}
