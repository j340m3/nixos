{
  config,
  pkgs,
  lib,
  constants,
  ...
}:

let
  settings = {
    enable_rollback = true;
    sprint_speed = 10;
    hudbars_autohide_stamina = false;
    address = "minetest.kauderwels.ch";
    remote_port = 30000;
    server_announce = false;
    server_name = "Bergmänners";
    server_description = "Se server wo se Bergmänner hosten";
    enable_damage = true;
    creative_mode = false;
    name = "kauderwelsch";
    enable_ipv6 = true;
    ipv6_server = true;
    enable_fire = true;
  };
  confFile = pkgs.writeText "luanti-server.conf" (
    lib.concatStrings (
      lib.mapAttrsToList (
        n: v: "${n} = ${if builtins.isBool v || builtins.isInt v then toString v else v}\n"
      ) settings
    )
  );
in
{
  environment.systemPackages = with pkgs; [
    borgbackup
  ];

  services.minetest-server.enable = true;
  # the pinned nixpkgs module hardcodes the client binary pkgs.luanti, which
  # drags sdl2-compat/sdl3/zenity/gtk4/gst-plugins-bad/flite onto a headless
  # host. run the dedicated server build with the same config values and the
  # same --gameid/--port; --server is dropped because luantiserver rejects it.
  systemd.services.minetest-server.serviceConfig.ExecStart =
    lib.mkForce "${pkgs.luanti-server}/bin/luantiserver --config ${confFile} --gameid voxelibre --port 30000";
  # The game dir is host-managed; a previous cleanup disabled mcl_spawn,
  # which makes mcl_void_damage index a nil global at startup. Re-enable it
  # before launch and fail clearly if the mod files themselves are gone.
  # Luanti >= 5.16 (nixpkgs 26.11, self-update 2026-10-19) loads mods that
  # are absent from world.mt; the June-2024 VoxeLibre copy still ships a
  # mcl_void_damage that indexes mcl_spawn too early, so the server got
  # stuck in a restart loop. Explicitly disable it like mcl_spawn above
  # until the game dir is upgraded wholesale.
  systemd.services.minetest-server.preStart = lib.mkAfter ''
    world=/var/lib/minetest/.minetest/worlds/world/world.mt
    game=/var/lib/minetest/.minetest/games/voxelibre
    if [ -f "$world" ]; then
      if ! ${pkgs.gnugrep}/bin/grep -q '^load_mod_mcl_spawn = true$' "$world"; then
        ${pkgs.gnused}/bin/sed -i '/^load_mod_mcl_spawn[[:space:]]*=/d' "$world"
        echo 'load_mod_mcl_spawn = true' >> "$world"
      fi
      if ! ${pkgs.gnugrep}/bin/grep -q '^load_mod_mcl_void_damage = false$' "$world"; then
        ${pkgs.gnused}/bin/sed -i '/^load_mod_mcl_void_damage[[:space:]]*=/d' "$world"
        echo 'load_mod_mcl_void_damage = false' >> "$world"
      fi
    fi
    if ! ${pkgs.findutils}/bin/find "$game/mods" -maxdepth 2 -type d -name mcl_spawn | ${pkgs.gnugrep}/bin/grep -q .; then
      echo "minetest: mcl_spawn missing from $game; restore the VoxeLibre game directory" >&2
      exit 1
    fi
  '';
  networking.firewall.allowedTCPPorts = [ 30000 ];
  networking.firewall.allowedUDPPorts = [ 30000 ];

  sops.secrets."borg/luanti" = {
    sopsFile = ../secrets/hosts/${config.networking.hostName}/secrets.yaml;
  };

  services.borgbackup.jobs.minetest = {
    paths = "/var/lib/minetest/.minetest";
    encryption.mode = "none";
    environment.BORG_RSH = "ssh -i ${config.sops.secrets."borg/luanti".path}";
    repo = "borg@${constants.host.woody.ip}:.";
    compression = "auto,lzma";
    startAt = "daily";
    preHook = "systemctl stop minetest-server";
    postHook = "systemctl start minetest-server";
  };

  # Send an email whenever auto upgrade fails
  systemd.services."borgbackup-job-minetest".onFailure =
    lib.mkIf config.systemd.services."notify-telegram@".enable
      [ "notify-telegram@%i.service" ];

}
