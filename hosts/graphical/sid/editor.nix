{pkgs,...}:{
  environment.systemPackages = [
    pkgs.zed-editor
  ];
  hardware.graphics.enable = true;

}
