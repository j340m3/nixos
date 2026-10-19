_:

{
  # This is on by default, making auto-cpufreq unable to work
  services.power-profiles-daemon.enable = false;

  powerManagement.enable = true;
  powerManagement.cpuFreqGovernor = "powersave";
  powerManagement.powertop.enable = true;
  services.thermald.enable = true;
  services.auto-cpufreq.enable = true;
  services.auto-cpufreq.settings = {
    battery = {
      governor = "schedutil";
      turbo = "never";
    };
    charger = {
      governor = "schedutil";
      turbo = "auto";
      energy_performance_preference = "balance_power";
      energy_perf_bias = "balance_power";
    };

  };
  # services.ollama = {
  #   enable = true;
  #   acceleration = false;
  #   environmentVariables = {
  #     OLLAMA_CONTEXT_LENGTH="32768";
  #   };
  # };
}
