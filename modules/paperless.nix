{
  config,
  pkgs,
  lib,
  ...
}:
{
  environment.etc."paperless-admin-pass".text = "admin";
  services.paperless = {
    enable = true;
    passwordFile = "/etc/paperless-admin-pass";
    settings = {
      PAPERLESS_TIKA_ENABLED = true;
      PAPERLESS_TIKA_ENDPOINT = "http://127.0.0.1:${toString config.services.tika.port}";
      PAPERLESS_TIKA_GOTENBERG_ENDPOINT = "http://127.0.0.1:${toString config.services.gotenberg.port}";
      PAPERLESS_OCR_LANGUAGE = "deu+eng";
      # PAPERLESS_APP_TITLE = "paperless.chungus.private";
      PAPERLESS_CONSUMER_IGNORE_PATTERN = builtins.toJSON [
        ".DS_STORE/*"
        "desktop.ini"
      ];
      PAPERLESS_EMAIL_TASK_CRON = "0 */8 * * *"; # “At minute 0 past every 8th hour.”

      # https://github.com/paperless-ngx/paperless-ngx/discussions/4047#discussioncomment-7019544
      # https://github.com/paperless-ngx/paperless-ngx/issues/7383
      PAPERLESS_OCR_USER_ARGS = {
        "invalidate_digital_signatures" = true;
      };
      PAPERLESS_CONVERT_TMPDIR = "/var/tmp/paperless";
      PAPERLESS_SCRATCH_DIR = "/var/tmp/paperless-scratch";
    };
  };

  services.tika = {
    enable = true;
    enableOcr = true;
    package = pkgs.tika;
  };

  services.gotenberg = {
    enable = true;
    timeout = "300s";
    port = 3214;
  };

  systemd.services.gotenberg = {
    environment.HOME = "/run/gotenberg";
    serviceConfig = {
      SystemCallFilter = lib.mkAfter [ "@chown" ]; # TODO remove when fixed (https://github.com/NixOS/nixpkgs/issues/349123)
      WorkingDirectory = "/run/gotenberg";
      RuntimeDirectory = "gotenberg";
    };
  };

}