# flake-file (denful/flake-file) — auto-generated flake.nix for dendritic setups

- Sources: https://github.com/denful/flake-file (was `vic/flake-file`; GitHub still
  redirects), docs https://flake-file.denful.dev, README repo root (accessed
  2026-10-21, rev `main`, ~167 commits, Apache-2.0, 162★). Source files read:
  `modules/default.nix`, `modules/options/{default,inputs,outputs}.nix`,
  `modules/{write-flake,write-lock,flake-parts,import-tree}.nix`,
  `modules/dendritic/{default,dendritic,basic,nixpkgs,systems}.nix`,
  `dev/modules/_lib/default.nix`, `templates/dendritic/{flake.nix,modules/dendritic.nix}`.
- Companion page: Dendrix https://dendrix.denful.dev/Dendritic.html (book repo:
  github.com/vic/dendrix, still the edit target; property list dumped below).
- One-liner: "Generate flake.nix from module options. Input and Output schemas.
  Works with flakes, unflake, npins, lon, niv or tack."
- Naming status: README banner — *"NOTE: Den no longer relates to the
  'Dendritic' name … the official dendritic repo no longer considers this
  Dendritic."* flake-file itself dates back to `vic/` and the Dendrix docs still
  recommend it for the dendritic pattern; treat the banner as Vic's framing of
  the `den` framework, not a deprecation of flake-file.
- The repo eats its own cooking: its own `flake.nix` is just
  `outputs = _: import ./modules;` — everything (incl. this doc's sources) is a
  module under `modules/`.

## a) What `flakeModules.dendritic` actually sets up

Nix expose two granularities: `flake-file.flakeModules.{default,dendritic,…}`
(plural, flake-parts style; used in current docs/templates) plus
`flake-file.flakeModules.flake` for *non-flake-parts* flakes and backends
`{npins,lon,niv,unflake,tack,flakeless-parts}` — from `modules/default.nix`
(source tree, read verbatim):

```nix
default.imports = [ base ./write-flake.nix ./flake-parts.nix ];
base.imports = [ ./options ./write-inputs.nix ./write-lock.nix ];
dendritic.imports = [ ./dendritic ];
```

`flakeModules.dendritic` = `modules/dendritic/default.nix`, which imports four
submodules:

1. **`dendritic.nix`** (verbatim):

   ```nix
   { inputs, lib, ... }: {
     imports = [
       (inputs.flake-parts.flakeModules.modules or { })
       (inputs.flake-file.flakeModules.import-tree or { })
     ];

     flake-file.inputs = {
       flake-parts.url = lib.mkDefault "github:hercules-ci/flake-parts";
       flake-parts.inputs.nixpkgs-lib.follows = lib.mkDefault "nixpkgs";
     };

     flake-file.outputs = lib.mkDefault "dendritic";

     flake.modules = { };
   }
   ```

   - `inputs.flake-parts.flakeModules.modules` — flake-parts' own module that
     provides the class-typed `flake.modules.<class>.<name>` options (the
     "everything is an aspect" store; see flake.parts
     /options/flake-parts-modules — "This module provides a generic modules
     flake output attribute … basic type checking so that the modules can't be
     imported into the wrong class"). The `flake.modules = { }` line just
     seeds the store.
   - `import-tree` submodule merely declares the input
     (`flake-file.inputs.import-tree.url = mkDefault "github:denful/import-tree"`).
   - `flake-file.outputs = "dendritic"` — a named preset string; resolved by
     `modules/options/outputs.nix`, verbatim:

     ```nix
     easyOutputs = {
       default = ''inputs: import ./outputs.nix inputs'';
       flake-file = ''inputs: (import ./flake-file.nix).outputs inputs'';
       flake-module = ''inputs: (inputs.nixpkgs.lib.evalModules {
           specialArgs = { inherit inputs; inherit (inputs) self; };
           modules = [ inputs.flake-file.flakeModules.flake ./flake-file.nix ];
         }).config.outputs inputs'';
       import-tree = ''inputs: (inputs.nixpkgs.lib.evalModules {
           specialArgs = { inherit inputs; inherit (inputs) self; };
           modules = [ (import-tree ./modules) ];
         }).config.outputs inputs'';
       flake-parts = ''inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } ./modules'';
       dendritic = ''inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules)'';
     };
     options.flake-file.outputs = lib.mkOption {
       type = lib.types.str;
       default = "default";
       apply = output: easyOutputs.${output} or output;  # named presets expand,
       # otherwise the raw string is the literal outputs body
     };
     ```

2. **`basic.nix`**: imports `flakeModules.default` + `flakeModules.import-tree`
   and declares flake-file's own input
   (`flake-file.inputs.flake-file.url = mkDefault "github:denful/flake-file"`).
3. **`nixpkgs.nix`**:
   `flake-file.inputs.nixpkgs.url = mkDefault "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst"`.
4. **`systems.nix`** (verbatim, the *only* option flakeModule.dendritic forces
   beyond inputs):

   ```nix
   { lib, ... }: { systems = lib.mkDefault lib.systems.flakeExposed; }
   ```

   `mkDefault` → any module can narrow it (e.g. `systems = [ "x86_64-linux"
   "aarch64-linux" ]`) without `mkForce`.

So: importing it brings (i) all `flake-file.*` options + write-flake app +
checks, (ii) auto-import of `./modules` via import-tree (its default filter
skips `/_` paths and non-`.nix` files — see
[sources/import-tree.md](import-tree.md) for the verified filter), (iii) the
flake-parts `flake.modules` aspect classes, (iv) a `systems` default, and the
generated flake.nix ends up literally:

```nix
# DO-NOT-EDIT. This file was auto-generated using github:denful/flake-file.
# Use `nix run .#write-flake` to regenerate it.
{
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);

  inputs = {
    flake-file.url = "github:denful/flake-file";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs-lib";
    };
    import-tree.url = "github:denful/import-tree";
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
    nixpkgs-lib.follows = "nixpkgs";
  };
}
```

(verbatim `templates/dendritic/flake.nix`; note its
`flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs-lib"` differs from the
current `dendritic.nix` default `"nixpkgs"` — template predates a default
tweak. Both are safe chains.)

The `dendritic` **template** itself is one file:
`templates/dendritic/modules/dendritic.nix` =
`{ inputs, ... }: { imports = [ inputs.flake-file.flakeModules.dendritic ]; }`.

## b) Declaring inputs inside a feature module

Namespace is `flake-file.inputs.<name>` (Dendritic.html example uses the same
`flake-file.inputs.nixvim.url` form). Schema from
`modules/options/inputs.nix` + Options Reference:

- leaf fields: `url` (str, default ""), `type` (enum
  `indirect|path|git|mercurial|tarball|file|github|gitlab|sourcehut`),
  `submodules`, `shallow`, `lfs` (bool/null, default null → omitted), `owner`,
  `repo`, `path`, `id`, `dir`, `narHash`, `rev`, `ref`, `host` (str, default
  ""), `flake` (bool, default true), `follows` (null or str "flake input path
  to follow"), plus recursive `inputs.<dep>.follows` /
  `inputs.<dep>.autoFollow` (bool, default true) for nested deps.
- Full options reference also covers top-level `description`, `nixConfig`
  (free-form attrset, same syntax as flake `nixConfig`), `outputs`, style
  (`style.sep.*`, `style.sortPriority.*` — controls layout of the generated
  file), `write-hooks`/`check-hooks`/`check-files`, `prune-lock.{enable,program}`,
  `auto-follow.enable`, `formatter`, `do-not-edit`, `trackPinUrls`.
- Doc-book example (verbatim):

  ```nix
  flake-file = {
    description = "my awesome flake";
    nixConfig = {};
    inputs.nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
    inputs.nixpkgs-lib.follows = "nixpkgs";
    inputs.my-tool.flake = false;
    inputs.my-tool.url = "github:owner/my-tool";
    inputs.dep.inputs.nixpkgs.follows = "nixpkgs";
  };
  ```

- Serializer (`dev/modules/_lib/default.nix`, `inputsExpr`): each input's
  declared, non-default fields are emitted **verbatim as attrs of the input
  expression** — `flake = false` only when explicitly set to false; `follows`
  and nested `inputs` kept when non-empty. Single-attribute paths collapse
  (`my-tool.url = "…"` instead of `my-tool = { url = "…"; }`), other attrs stay
  grouped.

Concrete recipes for this repo's cases:

```nix
# two-level follows chain (home-manager pinning our nixpkgs)
flake-file.inputs.home-manager = {
  url = "github:nix-community/home-manager/release-25.05";
  inputs.nixpkgs.follows = "nixpkgs";
};

# dual nixpkgs — just two independent lazyAttrs entries, no conflict
flake-file.inputs = {
  nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
  nixpkgs-master.url = "github:nixos/nixpkgs/master";
};

# flake=false
flake-file.inputs.my-tool = {
  url = "github:owner/my-tool";
  flake = false;
};

# shallow git — PUT THE PARAMS IN THE URL STRING:
flake-file.inputs.chaotic.url = "git+https://github.com/chaotic-cx/nyx.git?shallow=1";
```

> **CONTRADICTION (verified locally, 2026-10-21, Nix 2.34.9):** the Options
> Reference advertises typed fields `shallow`, `ref`, `rev`, `type`,
> `owner`/`repo`, `dir`, … as input schema options, and the serializer emits
> them verbatim into the generated flake.nix — but this machine's Nix
> *rejects* them:
> `error: unexpected flake input attribute 'shallow'` and
> `error: unexpected flake input attribute 'ref'` (input expression attrset
> whitelist is `url`, `flake`, `follows` + nested `inputs`).
> Convention for **flake.nix backends**: encode shallow/ref/narHash the old
> way, in the `url` string (`git+https://…?shallow=1&ref=main`,
> `github:owner/repo?ref=x`). The typed fields are safe for the npins/lon/niv/
> tack pin backends (their pin formats do accept such fields). Upstream tests
> evidently cover the pin backends for these fields.
> Positive local test: `flake = false` + two-level nested follows lock cleanly
> (`Added input 'hm/nixpkgs': follows 'base'`).

## c) Does it touch flake.lock?

**No, by default.** `write-flake` (modules/write-flake.nix, verbatim logic):

```nix
cd ${config.flake-file.intoPath}
if ! cmp -s ${formatted pkgs} flake.nix; then
  cat ${formatted pkgs} > flake.nix
fi
${staleLockWarning pkgs}   # only when auto-follow.enable
'' nix flake lock
${autoFollowCommand pkgs}  # flake-edit follow (rewrites follows into flake.nix)
nix flake lock --offline''
${hooks}                   # configured write-hooks
```

- Without `flakeModules.auto-follow`: `write-flake` rewrites **only
  flake.nix** (and only if it differs — a `cmp` guard, so no spurious
  mtime/commits) and never runs `nix flake lock`. Lock updates stay the
  ordinary `nix flake lock / update <input>` workflow; Nix re-locks lazily on
  next evaluation anyway.
- The only built-in lock *touch*: `compareLock`-style **stale-lock warning** for
  Nix/Lix keeping an old lock node when only the `flake` attribute flips
  (upstream issue #114): it greps flake.lock with `jq` and prints
  *"flake-file: flake.lock records a different `flake` attribute for: …
  refresh with: nix flake update <stale>"* — a warning, not a rewrite.
- **`flakeModules.auto-follow`** (opt-in; `flake-file.auto-follow.enable = true`):
  *"write-flake updates flake.lock, runs `flake-edit follow`, and updates the
  lock again"* (needs `pkgs.flake-edit ≥ 0.3.5`). It synthesizes *nested*
  follows (`flake-parts.inputs.nixpkgs-lib.follows = …`) automatically; explicit
  follows are preserved; exclude per nested input with
  `flake-file.inputs.crane.inputs.nixpkgs.autoFollow = false;` (exclusion +
  explicit follows conflict → error). This mode **does** rewrite both files.
- **Lock flattening** (`flakeModules.allfollow` / `flakeModules.nix-auto-follow`,
  opt-in): *"Rewrites only flake.lock after generation"* — spikespaz/allfollow
  or fzakaria/nix-auto-follow configured through
  `flake-file.prune-lock.{enable,program}`. Keeps generated follows out of
  flake.nix; deduplication lives only in the lock.
- **The docs comparison table** (Auto-follows guide): source of truth =
  follows in flake.nix vs rewritten relationships in flake.lock; pick **one**
  of the two mechanisms, not both.
- `write-lock` (modules/write-lock.nix) is just a dispatcher: detects which
  lockfile exists (flake.lock → write-flake, npins/sources.json → write-npins,
  …) and execs the matching writer.

**Implication for this repo's hand-tuned follows:** adopt with *no* auto-follow
and *no* prune-lock modules. Transcribe the ~20 inputs' existing follows graph
faithfully into `flake-file.inputs` (incl. two-level chains); the generator is
then a faithful serializer and flake.lock stays untouched. Dendrix docs
itself shows manual two-level follows in dendritic setups
(`flake-file.inputs.nixpkgs-lib.follows = "nixpkgs"`).

## d) The regeneration loop

- **Daily commands** (from migrate-flake-parts / how-it-works / guides):

  ```sh
  nix run .#write-flake    # regenerate flake.nix from flake-file.* options
  nix flake check          # must stay green: check includes check-flake-file
  ```

  `write-flake` = a writeShellApplication exported by the flakeModule through
  flake-parts core: `perSystem.packages.write-flake` and
  `perSystem.checks.check-flake-file` (modules/flake-parts.nix: `packages =
  lib.mapAttrs (_: f: f pkgs) config.flake-file.apps; checks.check-flake-file =
  config.flake-file.check-flake-file pkgs;`). The check is
  `diff -u ${root}/flake.nix ${formatted}` over `check-files` (default:
  `flake.nix`, `flake.lock`) — if stale, `nix flake check` FAILS. Add it to CI.
  Tip (templates guide): run write-flake from a devshell command or git
  pre-commit hook to keep flake.nix always in sync.
- **When to regenerate:** whenever the `flake-file.*` option tree changes —
  add/rename/remove an input, change a url/follows, description, nixConfig,
  outputs preset, style. "Run the same command whenever your input changes and
  they will be reflected into the static flake.nix" (migrate-flake-parts).
  Writing ordinary feature-module code does *not* need regeneration.
- **Bootstrap (chicken-and-egg):** before flake-file is an input of the flake,
  generation runs **outside** the flake via nix-shell against flake-file itself
  (docs: Try-it-now + migrate-flake-parts):

  ```sh
  mv flake.nix flake-file.nix   # keep a copy; inputs become modules
  nix-shell https://github.com/denful/flake-file/archive/main.tar.gz \
    -A write-flake --run write-flake \
    --arg modules ./modules --argstr outputs flake-parts
  ```

  Bootstrap args (reference/bootstrap): `modules` (file or dir; dir auto-wired
  through import-tree), `bootstrap` (bool/list of predefined inputs — none by
  default; includes import-tree/flake-file/flake-parts/nixpkgs URLs from
  `modules/bootstrap/inputs.nix`, all `mkDefault`), `outdir` (`--argstr`,
  default "."), `outputs` (`--argstr outputs flake-parts` = self-provided
  preset or any literal outputs expression like the dendritic one).
- **Non-circularity:** design-wise there's only one Nix expression flow: the
  *generated static* flake.nix contains just `outputs = inputs: mkFlake { … }
  (import-tree ./modules)`; add/remove-input churn lives in modules (`options`
  evaluation), and the file write is a serializer — the generated file never
  evaluates the modules' output logic to know its inputs (options come first).
  Practically: on the day flake-file IS an input,
  `nix run .#write-flake` evaluates the flake's own modules; the order when
  introducing a *new* input that modules ALSO import
  (`inputs.foo.flakeModules.…`) matters — declare its url, regen, `nix flake
  lock`, then activate the import (or re-bootstrap). Dropping a used input:
  remove the import first, else write-flake can't even evaluate
  (`inputs.foo` doesn't resolve). That constraint is inherent to "inputs are
  declared in the same module system" and is why the bootstrap app exists.

## e) How feature modules access `inputs`

Unchanged flake-parts dance; nothing dendritic removes it:

- Generated outputs (dendritic preset, verbatim):
  `inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules)`
  → **yes, `mkFlake { inherit inputs; }` still appears** in the generated
  flake.nix.
- flake-parts resolves each module's declared args via `functionArgs`
  (module functor introspection); `inputs` is among the standard flake-parts
  module arguments, so any module may write `{ inputs, lib, ... }:` — the
  migrate-flake-parts example comments it precisely: `# resolved flake inputs
  as specialArgs`.
- Template usage ({ inputs, ... }: imports =
  inputs.flake-file.flakeModules.dendritic) confirms `inputs` is available in
  auto-imported modules.
- Doc-Steve/mightyiam anti-pattern note applies as before: don't re-thread
  `inputs` through `specialArgs` of *lower-level* configs; reference it at the
  top level and pull config values from the top-level config.
- Convenience `self`-free access: the `import-tree` and `flake-module`
  outputs presets bind `specialArgs = { inherit inputs; inherit (inputs) self; }`
  explicitly (outputs.nix above) — only relevant for those presets.

## f) Caveats for this repo's shape (NixOS-only, restricted systems, perSystem, mkNixos)

- **`systems`**: flakeModule.dendritic sets `systems = lib.mkDefault
  lib.systems.flakeExposed` → override freely in one of your modules with
  `systems = [ "x86_64-linux" "aarch64-linux" ]` (mkDefault loses to your
  regular value — no `mkForce` needed). Worth overriding: flakeExposed means
  every exposed platform participates in perSystem/withSystem plumbing.
- **NixOS-only (no darwin):** unsupported-systems won't break anything —
  nothing in flake-file or dendritic imports darwin hjem; you just don't define
  `darwinConfigurations`. The restricted `systems` list keeps perSystem output
  surface sane. Dendritic.html's darwin examples are illustrative only.
- **perSystem:** `checks`/`packages` etc. keep working through flake-parts core;
  flake-file adds `packages.write-flake` and `checks.check-flake-file` to every
  system in your `systems` list (guarded via perSystem, so CI checks run per
  system).
- **`mkNixos` helper / `nixpkgs.hostPlatform = mkDefault system`:** the
  generated outputs function is a plain flake-parts `mkFlake`, so the host
  factory trio from [host-definition](concepts/host-definition.md) migrates
  unchanged (declare `flake.nixosConfigurations.<host> = nixosSystem { … }` in
  a top-level module; dendritic adds no special host machinery). Nothing
  flake-file-side rewrites `nixpkgs.hostPlatform` or `system` handling.
- **import-tree side effects:** every `.nix` under modules/ gets imported;
  non-module files (callPackage `.pkg.nix`, parked files) must keep the `/_`
  or `.pkg.nix` exclusion discipline (import-tree's `/_` rule applies through
  the dendritic outputs).
- **Generated-file discipline:** hand edits inside flake.nix are
  overwritten (`cat formatted > flake.nix` on every diffing run — do-not-edit
  header warns). Host-specific url hacks (e.g. old ssh git URLs) belong in
  flake-file.inputs declarations in modules. `check-flake-file` diffing uses
  `builtins.path` filtered to `check-files` (flake.nix + flake.lock only), so
  unrecommitted tree state doesn't churn the check hash.
- **Older wording**: Dendritic.html still advertises `vic/flake-file` and
  older docs/pages also write `flake-file.flakeModule.dendritic`
  (singular); current upstream exposes plural names
  (`flakeModules.{default,dendritic}`). Use the plural names.

## g) Dendrix property list (https://dendrix.denful.dev/Dendritic.html, verbatim headers)

Dendritic Nix = a pattern based on flake-parts' `modules` option
("aspect-oriented": each nix file provides config-values for the same aspect
across different configuration classes; `flake.modules.<class>.<aspect>`).
*Dendritic is a configuration pattern — a way-of-doing-; not a library nor a
framework.* Links Doc-Steve's guide. Its "Dendritic Advantages" list:

1. **No need to use `specialArgs` for communicating values** — passing
   `specialArgs` / `extraSpecialArgs` is *an anti-pattern in dendritic setups*;
   use let-bindings or custom flake-parts options to share across classes
   (example: user module `vic.nix` sharing `userName` between nixos/darwin/
   homeManager aspects).
2. **No file organization restrictions** — free to move/rename files per your
   mental model.
3. **All nix files have the same semantic meaning** — each `.nix` file has
   only one interpretation: "a flake-parts module".
4. **No manual file imports** — all files loaded at once; community library
   `vic/import-tree`; *"import-tree ignores any file that has an `/_` as part
   of its path"*.
5. **Minimal and focused flake.nix** — "flake.nix serves more as a manifest
   of dependencies and flake entrypoint"; *"some people go a step further and
   use `vic/flake-file` to manage their flake.nix automatically, by letting
   each flake-parts module also define the flake inputs needed by each
   module"* (with the vim.nix / `flake-file.inputs.nixvim.url` example).
6. **Feature centric instead of host centric** — quoting Pol Dellaiera,
   "Flipping the Configuration Matrix": *"the configuration is now structured
   around features, not hostnames … an inversion of configuration control"*;
   name aspects around usability concerns (e.g. `scrolling-desktop`,
   `macos-like-bindings`), not hostnames; hosts.nix then picks aspects
   (`flake.nixosConfigurations … modules = with inputs.self.modules.nixos; [ ai ssh vpn … ]`).
7. **Feature *closures*** — everything a feature needs is in one
   file/directory named for it; *"Paths become documentation"*.
8. **(*Incremental* features)** — extend features by creating
   `feature-x/advanced.nix` contributing to the same aspect; removing/adding
   files (or `_` mark for ignore) temporarily disables them during refactors.
9. **No dependencies** — pattern not framework; *"the Dendritic repository has
   no code at all"*; dendritic setups without flakes exist
   (vic/dendritic-unflake).
10. **Dendritic community** — Dendrix project goal: share generic
    user/host-independent dendritic configurations ("NUR for dendritic
    modules"; Trees + Layers for community configs).

Also on the page: a full ssh example file (let-bound `scpPort` shared across
nixos/darwin/homeManager aspects + perSystem), and hosts.nix example above.

## Relation to this repo (adoption sketch)

- flakeModule.dendritic gives: auto-import + `flake.modules` classes + a
  generated flake.nix — plug-in compatibility with the migration already
  planned in [migration-plan-notes](../syntheses/migration-plan-notes.md);
  run flake-parts' own `flakeModules.modules` (already planned) plus optionally
  import-tree/existing importTree shim can switch later.
- Keep: dual nixpkgs, hand-tuned two-level follows (declare per input, no
  auto-follow), `systems = [ "x86_64-linux" ]`/aarch64 explicit, mkNixos helper
  untouched, restricted perSystem lists.
- Guardrail: `perSystem.checks.check-flake-file` + `nix flake check` in CI from
  day one so generated flake.nix never drifts from the declared option tree.
- Deciding NOT to use: lock flattening (allfollow / nix-auto-follow) and
  auto-follow (`flake-edit`) — they would rewrite the hand-tuned lock/follows
  outside our declared graph.
