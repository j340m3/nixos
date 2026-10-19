{ self, ... }:

{
  flake.nixosConfigurations."lenny" = self.lib.mkNixos "lenny";
}
