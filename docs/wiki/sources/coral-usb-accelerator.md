# Source: Google Coral USB Accelerator — hardware specs

**URL:** https://coral.ai/docs/accelerator/datasheet/ (links to official PDF /static/files/Coral-USB-Accelerator-datasheet.pdf)
**Mirror/provenance of key figures:** Mouser datasheet HTML, https://www.mouser.com/datasheet/2/1572/Coral_USB_Accelerator_datasheet-3460241.pdf
**Accessed:** 2026-11-04
**Status:** current (product still listed by distributors Mouser, pi3g, Electromaker as of 2026-11-04)

## Key extracts

- The Coral USB Accelerator adds a Google Edge TPU ML accelerator coprocessor to a host via USB. Part number G950-06809-01 (also G950-01456-01 variant referenced). [sources/coral-usb-accelerator.md]
- **Edge TPU: 4 TOPS total peak performance (INT8); 2 TOPS per watt (0.5 W per TOPS).** [coral.ai datasheet page; Mouser datasheet HTML; thepihut.com product page]
- **Interface: USB 3.0 (USB 3.1 Gen 1) Type-C socket;** USB-C to Type-A cable (~300 mm) included. "For the best performance, use a USB 3.0 port." [Mouser datasheet; coral.ai get-started]
- Size **65 × 30 × 8 mm**, aluminium enclosure, four mounting holes; draws **around 2 W**. [thepihut; electromaker]
- Host support: Debian Linux (incl. Raspberry Pi), macOS 10.15+, Windows 10. One available USB port. [Mouser datasheet]
- On-board Edge TPU ASIC has **~8 MB SRAM** for model parameters; compiler reports ~6.91 MiB available for parameter caching, rest reserved for the inference executable. [Medium teardown, Kavalerov 2019; coral.ai compiler page, parameter-data-caching section]
- Example performance claim from Google: MobileNet v2 at almost **400 FPS** on one Edge TPU; TensorFlow Blog (Mar 2019): MobileNets for face detection **70–100 FPS**, food recognition **200 FPS** with the USB Accelerator. [coral.ai datasheet page; blog.tensorflow.org 2019-03]
- The USB Accelerator does **not** require the kernel `gasket` driver (that is for PCIe-based Coral devices); it works over plain USB on modern Linux. [frigate#10056 comment, 2025-10-23]

## Notes / caveats

- Google's original Coral product line had a quiet period; XDA Developers (2025) states Google stopped supporting the original Coral TPU lineup and most libraries had not been updated since 2022. The EDGE AI Working Group wiki (updated 2026-07-15) reports Coral is "back" with a new Coralboard announced at Google I/O 2026 — a next-generation direction, not a change to the USB Accelerator spec itself. Treat long-term software support as uncertain.
