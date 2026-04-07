{
  inputs,
  lib,
  ...
}:
let
  username = "donquezz";
in
{
  flake.modules.homeManager."${username}" =
    { pkgs, ... }:
    {
      imports = with inputs.self.modules.homeManager; [
        system-default
        # messaging
      ];
      home.username = "${username}";
    };
}
