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
    configureTika = true;
    database.createLocally = true;
    #dataDir = "/apps/paperless";
    settings = {
      PAPERLESS_TASK_WORKERS = 1;
      PAPERLESS_THREADS_PER_WORKER = 2;
      PAPERLESS_OCR_LANGUAGE = "deu+eng";
      # # PAPERLESS_APP_TITLE = "paperless.chungus.private";
      # PAPERLESS_CONSUMER_IGNORE_PATTERN = builtins.toJSON [
      #   ".DS_STORE/*"
      #   "desktop.ini"
      # ];
      # PAPERLESS_EMAIL_TASK_CRON = "0 */8 * * *"; # “At minute 0 past every 8th hour.”

      # # https://github.com/paperless-ngx/paperless-ngx/discussions/4047#discussioncomment-7019544
      # # https://github.com/paperless-ngx/paperless-ngx/issues/7383
      # PAPERLESS_OCR_USER_ARGS = {
      #   "invalidate_digital_signatures" = true;
      # };  
    };
  };

}