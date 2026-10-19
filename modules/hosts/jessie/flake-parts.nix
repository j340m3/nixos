{ self, ... }:

{
  flake.nixosConfigurations."jessie" = self.lib.mkNixos "jessie";
}
