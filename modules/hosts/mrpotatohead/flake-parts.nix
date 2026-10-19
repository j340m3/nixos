{ self, ... }:

{
  flake.nixosConfigurations."mrpotatohead" = self.lib.mkNixos "mrpotatohead";
}
