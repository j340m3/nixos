{ self, ... }:

{
  flake.nixosConfigurations."bootstrap-impermanent" = self.lib.mkNixos "bootstrap-impermanent";
}
