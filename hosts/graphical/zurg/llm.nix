{pkgs,inputs,...}:{
  nix.settings = {
    substituters = [
      "https://cache.nixos-cuda.org"
      "https://cache.chaotic.cx"
    ];
    trusted-public-keys = [
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      "chaotic.cachix.org-1:Zf7C6GVRqJjU8B/ihd+psPVKp3/7Or/FSvOP3/9aB8Y="
    ];
  };
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda.override {
      cudaArches = [ "52" ]; # Quadro M1200/M2200 (Maxwell) im ThinkPad P51
      cudaPackages = pkgs.cudaPackages_12; # CUDA 13 dropped Maxwell (sm_52)
    };
    environmentVariables = {
      # 1. Zwingt den Kontext auf ein kleineres Fenster (Standard ist oft 4K/8K oder mehr)
      # OLLAMA_CONTEXT_LENGTH = "2048";
    
      # 2. Komprimiert den Schlüssel-Wert-Cache im VRAM (spart massig VRAM)
      # OLLAMA_KV_CACHE_TYPE = "q8_0";
    
      # 3. Verhindert, dass Ollama parallel Slots für mehrere User im VRAM reserviert
      OLLAMA_NUM_PARALLEL = "1";
    };
  };
  environment.systemPackages = [
    inputs.opencode-dev.packages.${pkgs.system}.default
    pkgs.opencode
    pkgs.opencode-desktop
  ];
}
