# NixOS Config

Glossary for this repo's language: a flake that defines NixOS hosts, the
artifacts used to install them, and the guarantees those hosts must keep.

## Language

**Image**:
A prebuilt disk artifact used to install a fresh host (the bootstrap
artifacts). Not a word for how much disk a running host uses.
_Avoid_: using "image" for a running system's disk usage

**Installed footprint**:
The disk space a running host occupies: its system closure plus the Nix
store, logs, and state that live alongside it.
_Avoid_: image, size

**Update independence**:
The guarantee that a host updates itself from this repo, in place, with no
external machinery required.
_Avoid_: rebuildability (use only when talking about builds, not updates)

**Feature**:
A self-contained building block — a service, a desktop, an account, a whole
host — that bundles everything that concern needs across system and
user-home contexts. A feature is used by being listed where it applies, not
by being configured.
_Avoid_: module (that word covers machine-readable plumbing), role, package

**Aspect**:
A named value a feature publishes so other features can use it; it lies
dormant until something imports it.
_Avoid_: module output, option

**Host**:
A machine this flake boots and manages. A host is itself a feature: it
exists by listing the features it uses, and carries its own machine
reality (disks, hardware quirks) inline — nothing of a host lives in a
separate pile of helper files.
_Avoid_: directory (as the definition of a host), glue (there is none),
target

**WG hub**:
A host that terminates WireGuard tunnels for the fleet's mobile peers.
Not every WG hub takes part in the mesh, and "hub" is never a word for a
nebula lighthouse that doesn't serve WG peers.
_Avoid_: server, gateway

**Lighthouse**:
An anchor host of the nebula mesh: the rendezvous points mesh members
find each other through, and the entry/exit relays of the mesh.
_Avoid_: hub (reserve for WireGuard), master, server

**Homeserver**:
A host on the home network the public internet cannot reach; it serves the
home LAN and mesh members, and its public-name certificates must be issued
by DNS-01 because a webroot challenge needs a publicly reachable server.
_Avoid_: LAN-only host (it also serves the mesh), internal server

**Mesh port**:
A TCP port a service exposes to the mesh, admitted through both gatekeeping
layers: the mesh's own in-tunnel firewall and the host's interface firewall.
Opening one layer without the other silently drops the traffic — an
in-tunnel service can be reachable locally yet dead from a peer.
_Avoid_: exposed port (silent about the two layers), firewall port
