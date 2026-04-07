{
  inputs,
  self,
  ...
}:

let
  username = "jeromeb";
in
{
  flake.modules.nixos."${username}" =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    {

      imports = with inputs.self.modules.nixos; [
        yubikey
        stylix
        vscode
        # developmentEnvironment
      ];

      home-manager.users."${username}" = {
        imports = [
          inputs.self.modules.homeManager."${username}"
          inputs.self.modules.homeManager.stylix
        ];
      };

      users.users."${username}" = {
        isNormalUser = true;
        #initialPassword = "changeme";
        description = "Jerome";
        extraGroups = [
          "networkmanager"
          "wheel"
          "docker"
        ];
        shell = pkgs.zsh;
      };
      programs.zsh.enable = true;

      nixpkgs.config.allowUnfreePredicate =
        pkg:
        builtins.elem (lib.getName pkg) [
          "spotify"
          "apple_cursor"
        ];
    };

}
