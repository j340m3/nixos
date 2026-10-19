{ self, ... }:

{
  flake.nixosConfigurations."woody" = self.lib.mkNixos "woody";
}
