# Source: Coral Edge TPU software on NixOS — packaging and ecosystem status

**URLs:**
- https://github.com/NixOS/nixpkgs/issues/188719 — "libedgetpu: package and provide nixos module", opened 2022-08-28
- https://github.com/google-coral/pycoral — PyCoral Python API repo (submodules libcoral, libedgetpu; version-matched builds required)
- https://www.xda-developers.com/intels-cheapest-cpus-do-what-googles-coral-accelerators — XDA Developers, 2025 (Coral support status)
- https://github.com/blakeblackshear/frigate/issues/10056 — Frigate issue re Coral TPU deprecation, Oct 2025
**Accessed:** 2026-11-04

## Key extracts

- **nixpkgs has no libedgetpu/pycoral packaging.** Issue nixpkgs#188719 (2022-08-28) requests packaging libedgetpu + a NixOS module for the Coral USB Accelerator; the reported build of the edgetpu driver fails. No evidence in this repo or in nixpkgs (as found by search) of a merged package. Local grep of `/home/jeromeb/Dokumente/code/nixos` for "edgetpu|coral" in *.nix found nothing. [nixpkgs#188719; local repo grep]
- Installing Coral software on Linux normally means Google's `coral-edgetpu` apt repository (packages.cloud.google.com) + `libedgetpu1-std` (or `-max`) and `python3-pycoral` Debian packages; on NixOS these apt packages are not directly usable, so the runtime must be built from source or bundled manually — an extra integration hurdle. [coral.ai compiler/tflite-python download instructions; nixpkgs#188719]
- **Ecosystem maintenance risk:** XDA Developers (2025) states Google stopped supporting the original Coral TPU lineup and most libraries had not been updated since 2022; the gasket driver (PCIe devices) is unsupported on latest Linux (USB Accelerator does not use gasket). Frigate (2025-10) still supports USB Coral and notes the gasket issue does not apply to USB. [XDA 2025; frigate#10056]
- `pycoral` requires version-matched `libcoral`/`libedgetpu` builds (shared `TENSORFLOW_COMMIT` across submodules); mixing versions breaks. Debian guidance: install pycoral via apt, not pip. [pycoral GitHub README]
