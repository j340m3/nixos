{ inputs, ... }:
let
  constants = import ../global/_constants.nix;
in
{
  flake.modules.nixos.minetest =
    {
      config,
      pkgs,
      lib,
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
      # The engine jumps caused repeated fatal undeclared-global ModErrors with
      # the June-2024 VoxeLibre 0.87.2 copy in the data dir (mcl_void_damage ->
      # mcl_spawn, mcl_grindstone -> mcl_formspec load before their providers,
      # and luanti >= 5.16 additionally enables game mods absent from world.mt,
      # so world.mt 'false' entries do not disable them). Serve a pinned current
      # release from the nix store instead: LUANTI_GAME_PATH must contain a
      # gameid-named folder (the engine derives the gameid from the folder name,
      # game.conf 'name' is not authoritative).
      systemd.services.minetest-server.environment.LUANTI_GAME_PATH =
        let
          voxelibre = pkgs.fetchFromGitHub {
            owner = "VoxeLibre";
            repo = "VoxeLibre";
            rev = "0.92.3";
            hash = "sha256-IRx/sUqwm7UWCALF8EPP8C+DJEe5Dbv+d46EGl/sYfM=";
          };
        in
        pkgs.runCommand "voxelibre-game-0.92.3" { } ''
          mkdir -p $out && cp -r ${voxelibre} $out/voxelibre
        '';
      # Park the stale data-dir copy out of game discovery: direct children of
      # games/ are scanned as games, one level deeper are not.
      systemd.services.minetest-server.preStart = lib.mkAfter ''
        data=/var/lib/minetest/.minetest
        game=$data/games/voxelibre
        if [ -d "$game" ]; then
          mkdir -p "$data/games/.stale"
          mv "$game" "$data/games/.stale/0.87.2"
        fi
      '';
      networking.firewall.allowedTCPPorts = [ 30000 ];
      networking.firewall.allowedUDPPorts = [ 30000 ];

      sops.secrets."borg/luanti" = {
        sopsFile = ../../secrets/hosts/${config.networking.hostName}/secrets.yaml;
      };

      services.borgbackup.jobs.minetest = {
        paths = "/var/lib/minetest/.minetest";
        encryption.mode = "none";
        environment = {
          BORG_RSH = "ssh -i ${config.sops.secrets."borg/luanti".path}";
          # borg runs non-interactively: a dropped client security cache (or a
          # recreated repo) aborts the job with "Attempting to access a
          # previously unknown unencrypted repository!". This repo is a family
          # LAN backup over the mesh, so accept and resume automatically.
          BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK = "yes";
          BORG_RELOCATED_REPO_ACCESS_IS_OK = "yes";
        };
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

    };
}
