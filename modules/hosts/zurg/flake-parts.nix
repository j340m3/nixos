{ self, ... }:

{
  flake.nixosConfigurations."zurg" = self.lib.mkNixos "zurg";
}
