{pkgs,...}:{
  environment.systemPackages = [
    pkgs.zed-editor
  ];
  nixGL.vulkan.enable = true;

}
