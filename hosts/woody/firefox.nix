{
# Install firefox.
  
  programs.firefox = {
    enable = true;
    package = pkgs.firefox-esr;
    policies = {
      Cookies = {
        "Locked" = true;
        "Behavior" = "reject-tracker";
        "BehaviorPrivateBrowsing" = "reject-tracker";
        "DisableFirefoxAccounts" = true;
      };

      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DontCheckDefaultBrowser = true;
      DisablePocket = true;
      EnableTrackingProtection = {
          "Value" = true;
          "Locked" = true;
          "Cryptomining" = true;
          "Fingerprinting" = true;
          "Exceptions" = [];
      };

      OfferToSaveLogins = false;
      PasswordManagerEnabled = false;
      SanitizeOnShutdown = {
        "Cache" = true;
        "Cookies" = true;
        "Downloads" = false;
        "FormData" = true;
        "History" = false;
        "Sessions" = true;
        "SiteSettings" = true;
        "OfflineApps" = true;
        "Locked" = true;
      };

      SearchBar = "unified";

      Preferences = {
        # Privacy settings
        "extensions.pocket.enabled" = lock-false;
        "browser.newtabpage.pinned" = lock-empty-string;
        "browser.topsites.contile.enabled" = lock-false;
        "browser.newtabpage.activity-stream.showSponsored" = lock-false;
        "browser.newtabpage.activity-stream.system.showSponsored" = lock-false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = lock-false;

        # "browser.startup.homepage" = "https://duckduckgo.com";
        "browser.search.defaultenginename" = "DuckDuckGo";
        "browser.search.order.1" = "DuckDuckGo";

        "signon.rememberSignons" = false;
        "widget.use-xdg-desktop-portal.file-picker" = 1;
        "browser.aboutConfig.showWarning" = false;
        "browser.compactmode.show" = true;
        "browser.cache.disk.enable" = false; # Be kind to hard drive

        # Firefox 75+ remembers the last workspace it was opened on as part of its session management.
        # This is annoying, because I can have a blank workspace, click Firefox from the launcher, and
        # then have Firefox open on some other workspace.
        "widget.disable-workspace-management" = true;
      };

      ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "force_installed";
        };
        "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
          installation_mode = "force_installed";
        };
        "jid1-MnnxcxisBPnSXQ@jetpack" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/privacy-badger17/latest.xpi";
          installation_mode = "force_installed";
        };
        "extension@tabliss.io" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/tabliss/latest.xpi";
          installation_mode = "force_installed";
        };
        "gdpr@cavi.au.dk" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/consent-o-matic/latest.xpi";
          installation_mode = "force_installed";
        };
      };

      SearchEngines = {
        Default = "DuckDuckGo";
      };

      WebsiteFilter = {
        Block = ["https://9gag.com/"];
        Exceptions = [];
      };
    };
  };