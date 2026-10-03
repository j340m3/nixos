{pkgs, inputs, ...}: {
  nixpkgs.overlays = [
    (final: super: {
      makeModulesClosure = x:
        super.makeModulesClosure (x // {allowMissing = true;});
    })
  ];

  environment.systemPackages = [
    (pkgs.callPackage "${inputs.oom-hardware}/raspberry-pi/packages/rpi-utils" {})
  ];

  users.groups.spi = { };
  services.udev.extraRules = ''
    SUBSYSTEM=="spidev", KERNEL=="spidev0.0", GROUP="spi", MODE="0660"
  '';

  console = {
    earlySetup = true;
    font = "ter-v32n";
    packages = with pkgs; [terminus_font];
  };

  boot.kernelParams = [
    "8250.nr_uarts=1"
    "vc_mem.mem_base=0x3ec00000"
    "vc_mem.mem_size=0x20000000"
    "console=ttyS0,115200"
    "console=tty1"
    "plymouth.ignore-serial-consoles"
    "snd_bcm2835.enable_hdmi=1"
    "snd_bcm2835.enable_headphones=1"
    "psi=1"
    "iommu=force"
    "iomem=relaxed"
    "swiotlb=131072"
  ];

  hardware.raspberry-pi."4" = {
    xhci.enable = false;
    overlays = {
      cpu-revision.enable = true;
      audremap.enable = true;
      vc4-kms-v3d.enable = true;
      cpi-disable-pcie.enable = true;
      cpi-disable-genet.enable = true;
      cpi-uconsole.enable = true;
      cpi-i2c1.enable = false;
      cpi-spi4.enable = false;
      cpi-bluetooth.enable = true;
    };
  };

  # dwc2 moved out of hardware.raspberry-pi.4 into the firmware config
  boot.loader.generic-extlinux-compatible.useGenerationDeviceTree = false;
  hardware.raspberry-pi.configtxt = {
    settings.cm4.otg_mode = null;
    deviceTreeOverlays.cm4 = [
      {
        dwc2.dr_mode = "host";
      }
    ];
  };

  hardware.deviceTree = {
    enable = true;
    filter = "bcm2711-rpi-cm4.dtb";
    overlaysParams = [
      {
        name = "bcm2711-rpi-cm4";
        params = {
          ant2 = "on";
          audio = "on";
          spi = "off";
          i2c_arm = "on";
        };
      }
      {
        name = "cpu-revision";
        params = {cm4-8 = "on";};
      }
      {
        name = "audremap";
        params = {pins_12_13 = "on";};
      }
      {
        name = "vc4-kms-v3d";
        params = {
          cma-384 = "on";
          nohdmi1 = "on";
        };
      }
    ];
  };
}

