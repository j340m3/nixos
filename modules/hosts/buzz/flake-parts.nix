{ self, ... }:

{
  flake.nixosConfigurations."buzz" = self.lib.mkNixos "buzz";
}
