{ self, ... }:

{
  flake.nixosConfigurations."rex" = self.lib.mkNixos "rex";
}
