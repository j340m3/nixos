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
  # are absent from world.mt, and a world.mt 'load_mod_mcl_void_damage =
  # false' is still ignored there ('false' disables only user-installed
  # worldmods, not game mods). The June-2024 VoxeLibre copy declares no
  # dependency between the two, so init runs before mcl_spawn defines its
  # global. Restore the missing dependency - load order then guarantees
  # the global exists - until the game dir is upgraded wholesale.
  # ponytail: formal fix is rebuilding the game dir to a current VoxeLibre.
  systemd.services.minetest-server.preStart = lib.mkAfter ''
    world=/var/lib/minetest/.minetest/worlds/world/world.mt
    game=/var/lib/minetest/.minetest/games/voxelibre
    if [ -f "$world" ]; then
      if ! ${pkgs.gnugrep}/bin/grep -q '^load_mod_mcl_spawn = true$' "$world"; then
        ${pkgs.gnused}/bin/sed -i '/^load_mod_mcl_spawn[[:space:]]*=/d' "$world"
        echo 'load_mod_mcl_spawn = true' >> "$world"
      fi
    fi
    void_damage=$game/mods/ENVIRONMENT/mcl_void_damage/mod.conf
    if ! ${pkgs.gnugrep}/bin/grep -qs 'depends = .*mcl_spawn' "$void_damage"; then
      ${pkgs.gnused}/bin/sed -i 's/^depends = /depends = mcl_spawn, /' "$void_damage"
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
