{
  config, lib, pkgs, ...
} : {
  services.swapspace.enable = true;
  services.swapspace.settings = {
    swappath="/nix/swapfile";
    lower_freelimit=50;
    upper_freelimit=70;
    freetarget=60;
    buffer_elasticity=100;
    cache_elasticity=100;
    cooldown=1;
  };
  # Source: https://manpages.ubuntu.com/manpages/focal/man8/swapspace.8.html
  services.swapspace.extraArgs = ["-z" "v"]; # --> Necessary for btrfs

  boot.kernel.sysctl = { "vm.swappiness" = 5;};

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
}
