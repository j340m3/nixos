{ self, ... }:

{
  flake.nixosConfigurations."pricklepants" = self.lib.mkNixos "pricklepants";
}
