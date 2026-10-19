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
