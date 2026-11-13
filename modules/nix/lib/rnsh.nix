# Patched rnsh runtime shared by every reticulum feature (transport daemon,
# ssh shim, nix-daemon bridge, borg bridge): the RNS site-packages copy with
# the two local rnsh patches applied, a python env around it, and the `rnsh`
# wrapper that puts the patched tree on PYTHONPATH.
#
# A function (factory-style, same pattern as borgClientJob) because the
# result depends on the host: `lxmf` toggles the lxmf package inside the
# python env, and every feature must build with the SAME flag the transport
# core uses (isPublic) or the binary/closure paths diverge per caller.
{ lib, ... }:
{
  flake.lib.rnsh =
    { pkgs, lxmf ? false }:
    let
      rnspython = pkgs.python3.withPackages (ps: [ ps.rns ] ++ lib.optional lxmf ps.lxmf);
      rnsPatched = pkgs.runCommand "rns-rnsh-streaming" { } ''
        mkdir -p "$out"
        cp -r ${pkgs.python3Packages.rns}/${pkgs.python3.sitePackages}/RNS "$out/RNS"
        substituteInPlace "$out/RNS/Utilities/rnsh/initiator.py" \
          --replace-fail \
            'data_buffer = bytearray(sys.stdin.buffer.read()) if not os.isatty(sys.stdin.fileno()) else bytearray()' \
            'data_buffer = bytearray()'
        # nix flows must tolerate slow peers (1 GB boxes under swap pressure);
        # upstream floors the version handshake at 5 s, which flaked on
        # pricklepants during its memory-thrash incident (2026-11-07).
        # 2026-11-13: an 80x multiplier is toxic on slow multi-hop paths -
        # whole-second rtt makes the version wait tens of minutes, which
        # looked like a 50% session wedge from pricklepants to woody.
        # Clamp: at least 30 s, at most 120 s.
        substituteInPlace "$out/RNS/Utilities/rnsh/initiator.py" \
          --replace-fail \
            'vm = _pq.get(timeout=max(outlet.rtt * 20, 5))' \
            'vm = _pq.get(timeout=min(max(outlet.rtt * 20, 30), 120))'
      '';
      rnsh = pkgs.writeShellScriptBin "rnsh" ''
        export PYTHONPATH=${rnsPatched}''${PYTHONPATH:+:$PYTHONPATH}
        exec ${rnspython}/bin/rnsh "$@"
      '';
    in
    {
      inherit rnspython rnsPatched rnsh;
    };
}
