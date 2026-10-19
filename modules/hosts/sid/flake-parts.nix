{ self, ... }:

{
  flake.nixosConfigurations."sid" = self.lib.mkNixos "sid";
}
