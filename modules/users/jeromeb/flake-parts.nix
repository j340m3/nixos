{
  inputs,
  ...
}:
{
  # Manage a user environment using Nix
  # https://github.com/nix-community/home-manager

  flake-file.inputs = {
    tinted-schemes = {
      flake = false;
      url = "github:tinted-theming/schemes";
    };
  };
}
