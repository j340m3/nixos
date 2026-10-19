{ self, ... }:

{
  flake.nixosConfigurations."bootstrap" = self.lib.mkNixos "bootstrap";
}
