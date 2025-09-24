{ inputs
, lib
, config
, pkgs
, ...
}: {
  home.packages = with pkgs; [ 
    nixfmt-rfc-style
    nerd-fonts.victor-mono
    nil
  ];
  
  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;
    profiles = {
      default = {
        extensions = with pkgs.vscode-extensions; [
          catppuccin.catppuccin-vsc
          catppuccin.catppuccin-vsc-icons
          #streetsidesoftware.code-spell-checker
          dbaeumer.vscode-eslint
          esbenp.prettier-vscode
          #vscodevim.vim
          #rust-lang.rust-analyzer
          #haskell.haskell
          davidanson.vscode-markdownlint
          elmtooling.elm-ls-vscode
          unifiedjs.vscode-mdx
          jnoortheen.nix-ide
          christian-kohler.path-intellisense
        ];
        userSettings = {
          # Nix
          "nix.enableLanguageServer" = true;
          "nix.serverPath" = "nil";
          "nix.serverSettings" = {
            "nil" = {
              "formatting" = {
                "command" = ["nixfmt"];
              };
            };
          };
          "nix.suggest.path" = false;

          # Git
          "git.enableSmartCommit" = true;
          "git.confirmSync" = false;
          "git.autofetch" = true;
          "files.autoSave" = "afterDelay";

          "editor.fontFamily" = "VictorMono Nerd Font Mono";
          "editor.snippetSuggestions" = "none";
          "terminal.integrated.fontFamily" = "VictorMono Nerd Font Mono";
          "files.insertFinalNewline" = true;
          "editor.fontLigatures" = true;
          "editor.formatOnSave" = true;
          "editor.suggest.showWords" = false;
          "editor.acceptSuggestionOnCommitCharacter" = false;
          "emmet.showExpandedAbbreviation" = "never";
          "editor.renderLineHighlight" = "none";

          # Minimal mist conifg

          "editor.scrollbar.vertical" = "hidden";
          "window.commandCenter" = false;
          "window.titleBarStyle" = "custom";
          "breadcrumbs.enabled" = true;
          #"workbench.sideBar.location" = "right";
          "workbench.statusBar.visible" = true;
          "workbench.startupEditor" = "none";
          "workbench.tree.indent" = 22;
          "workbench.tree.renderIndentGuides" = "onHover";

          # ###

          "editor.tabSize" = 2;
          "editor.bracketPairColorization.enabled" = true;
          "editor.detectIndentation" = false;
          "javascript.suggest.autoImports" = false;
          "typescript.suggest.autoImports" = false;
          "typescript.preferences.importModuleSpecifier" = "relative";
          "editor.lineNumbers" = "relative";

          "editor.tokenColorCustomizations" = {
            "textMateRules" = [
              {
                "scope" = [
                  "comment"
                  "storage.modifier"
                  "storage.type.php"
                  "keyboard.other.new.php"
                  "entity.other.attribute-name"
                  "fenced_code.block.language.markdown"
                  "keyboard"
                  "storage.modifier"
                  "storage.type"
                  "keyboard.control"
                  "constant.language"
                  "entity.other.attribute-name"
                  "entity.name.method"
                  "keyboard.control.import.ts"
                  "keyboard.control.import.tsx"
                  "keyboard.control.import.js"
                  "keyboard.control.flow.js"
                  "keyboard.control.from.js"
                  "keyboard.control.from.ts"
                  "keyboard.control.from.tsx"
                ];
                # "settings" = {
                #   "fontStyle" = "italic";
                # };
              }
            ];
          };

          "workbench.colorTheme" = "Catppuccin Frappé";
          "workbench.iconTheme" = "catppuccin-frappe";
        };
      };
    };
  };
}
