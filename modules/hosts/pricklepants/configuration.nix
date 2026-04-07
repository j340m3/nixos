{
  inputs,
  ...
}:
{
  flake.modules.nixos.pricklepants = {
    imports = with inputs.self.modules.nixos; [
      system-headless
      minetest
      vaultwarden
    ];
  };
  ###
}
