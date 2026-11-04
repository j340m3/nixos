# Host aspect (ADR 0014): flake.modules.nixos.sid is assembled by lib.mkNixos
# (modules/nix/lib.nix); the flake-parts.nix one-liner next to this file
# declares the host into the flake. inputs arrive via the transitional
# specialArgs in the factory, so the head args stay verbatim.
{ inputs, lib, ... }:

{
  flake.modules.nixos.sid =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [
        inputs.nixos-wsl.nixosModules.default
        inputs.self.modules.nixos.agent-md
      ];

      # The ./_editor.nix + ./_nvidia.nix host-local glue absorbed here.
      environment.systemPackages = [
        pkgs.qownnotes
        pkgs.zed-editor
      ];
      hardware.graphics.enable = true;

      # Former ./_nvidia.nix.
      services.xserver.videoDrivers = [ "nvidia" ];
      hardware.nvidia.open = true;

      environment.sessionVariables = {
        CUDA_PATH = "${pkgs.cudatoolkit}";
        EXTRA_LDFLAGS = "-L/lib -L${pkgs.linuxPackages.nvidia_x11}/lib";
        EXTRA_CCFLAGS = "-I/usr/include";
        LD_LIBRARY_PATH = [
          "/usr/lib/wsl/lib"
          "${pkgs.linuxPackages.nvidia_x11}/lib"
          "${pkgs.ncurses5}/lib"
        ];
        MESA_D3D12_DEFAULT_ADAPTER_NAME = "Nvidia";
      };

      hardware.nvidia-container-toolkit = {
        enable = true;
        mount-nvidia-executables = false;
      };

      systemd.services = {
        nvidia-cdi-generator = {
          description = "Generate nvidia cdi";
          wantedBy = [ "docker.service" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.nvidia-docker}/bin/nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml --nvidia-ctk-path=${pkgs.nvidia-container-toolkit}/bin/nvidia-ctk";
          };
        };
      };

      networking.hostName = "sid";
      nixpkgs.hostPlatform = "x86_64-linux";
      wsl.enable = true;
      wsl.defaultUser = "nixos";
      wsl.useWindowsDriver = true;
      nixpkgs.config.allowUnfree = true;

      system.stateVersion = "25.05";
    };
}
