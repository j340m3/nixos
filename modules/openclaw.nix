{openclaw, ...}:{
  imports = [ openclaw.nixosModules.default ];

  services.openclaw.enable = true;
  services.openclaw.domain = "kauderwels.ch"
}
