{config, lib, pkgs, ...} :{
  environment.systemPackages = with pkgs; [
    (vscode-with-extensions.override {
         # When the extension is already available in the default extensions set.
         vscodeExtensions = with vscode-extensions; [
           jnoortheen.nix-ide
           bbenoist.nix
           elmtooling.elm-ls-vscode
           ms-python.python
           charliermarsh.ruff
         ];
         vscode = vscodium;
       })
  ];
}
