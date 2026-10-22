{ pkgs, inputs, ... }:
{
  # The xfce aspect is imported once by the host configuration; listing it
  # here again would query _module.args.inputs during imports and recurse.
  nixpkgs.overlays = [
    inputs.affinity-nix.overlays.default
  ];
  users.mutableUsers = false;
  system.nixos.tags = [ "jeromeb" ];
  users.users.jeromeb = {
    isNormalUser = true;
    description = "Jerome Bergmann";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    hashedPassword = "$y$j9T$xI3Gvnwn4Q900uL0HQZHp/$fl5oFfnZWZWBz.6gPxvciND13komHHAXDqq6Yfpjn17";
    uid = 1002;
    packages = with pkgs; [
      firefox
      affinity-v3
      #  kate
      #  thunderbird
    ];
  };
  # Home Manager comes in via modules/_common/home-manager.nix; the host wires
  # the home tree under home-manager.users.jeromeb.
}
