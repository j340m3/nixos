{...}:{
  boot.kernelParams = [
    "hardlockup_panic=1"
    "panic=10" # reboot 10 seconds after panic
    "reboot=bios"
    "softlockup_panic=1"
  ];
  
  systemd.watchdog = {
    runtimeTime = "10s";
    rebootTime = "30s";
  };
}