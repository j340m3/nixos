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
exists by listing the features it uses.
_Avoid_: directory (as the definition of a host), target
