{config,lib,pkgs,...}:{
  fonts.packages = with pkgs; [
    nerd-fonts.monoid
    nerd-fonts.fira-code
    nerd-fonts.droid-sans-mono
    nerd-fonts.victor-mono
    nerd-fonts.comic-shanns-mono
  ];
}