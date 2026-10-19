{ self, ... }:

{
  flake.nixosConfigurations."slinky" = self.lib.mkNixos "slinky";
}
