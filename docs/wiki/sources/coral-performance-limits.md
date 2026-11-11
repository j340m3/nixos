# Source: Edge TPU performance limits — benchmarks, latency, throughput, thermals

**URLs:**
- https://coral.ai/docs/edgetpu/benchmarks/ (Edge TPU performance benchmarks, Google, copyright 2020)
- https://www.oneuptime.com/blog/post/2026-02-17-how-to-deploy-edge-ai-models-on-google-coral-edge-tpu-with-google-cloud-integration/view (secondary; "typical inference times 2–10 ms")
- https://docs.ultralytics.com/guides/coral-edge-tpu-on-raspberry-pi (Ultralytics YOLO26 on Coral; runtime std vs max and thermal throttling note)
- https://forum.khadas.com/t/usb-port-hangs-using-coral-ai-accelerator/18573 (real-world pycoral timing, VIM4, 2023-02)
**Accessed:** 2026-11-04

## Key extracts

**Peak compute:** 4 TOPS INT8, 2 TOPS/W (0.5 W per TOPS). Actual throughput depends on host CPU, USB speed, model; figures below measure model execution only (exclude input preprocessing) and come from C++ benchmarks; Python may be slower. [coral.ai benchmarks]

**Official latency table, time per single inference in ms (lower is better), TensorFlow Lite models:**

| Model | Desktop CPU | Desktop CPU + USB Accelerator | Embedded CPU (Cortex-A53 1.5 GHz) | Dev Board + Edge TPU |
|---|---|---|---|---|
| MobileNet v1 (224×224) | 53 | **2.4** | 164 | 2.4 |
| MobileNet v2 (224×224) | 51 | **2.6** | 122 | 2.6 |
| MobileNet v1 SSD (224×224) | 109 | **6.5** | 353 | 11 |
| MobileNet v2 SSD (224×224) | 106 | **7.2** | 282 | 14 |
| SqueezeNet (224×224) | 55 | **2.1** | 232 | 2 |
| Inception v1 (224×224) | 90 | **3.4** | 392 | 4.1 |
| DenseNet (224×224) | 380 | **20** | 1032 | 25 |
| ResNet-50 V1 (299×299) | 484 | **49** | 1763 | 56 |
| EfficientNet-EdgeTpu-S/M/L | 5431/8469/22258 | **5.1 / 8.7 / 25.3** | 705/1081/2717 | 5.5/10.6/30.5 |
| DeepLab V3 (513×513) | 394 | **52** | 1139 | 241 |
| VGG19 (224×224) | 1060 | **308** | 5538 | 357 |

[coral.ai benchmarks, Table 1]

**Real-world PyCoral measurement (classify_image, MobileNet V2, Khadas VIM4, Feb 2023):** first inference ~14.8 ms (includes loading model into Edge TPU memory); steady state ~4.6–4.9 ms per inference. [Khadas forum, 2023-02-18]

**Typical range cited in secondary coverage:** 2–10 ms per inference for common classification/detection models — fast enough for >30 FPS video. [oneuptime, 2026-02-17]

**Thermal / power:** two Edge TPU runtime builds exist — standard and "max" (higher clock, more performance, more heat; can cause thermal throttling; Ultralytics docs recommend cooling with the max runtime). Real-world measured temps 34–39 °C under webcam inference (standard vs max), within safe limits. [Ultralytics coral guide; YouTube Coral intro teardown/test, 2025]

**Scaling limits:** single Edge TPU handles one inference stream effectively at batch size 1; multiple models on one TPU cause cache-swap overhead (~8 MB SRAM); multiple TPUs can pipeline/segment a model (`--num_segments`) or run models in parallel to raise throughput. [coral.ai compiler]

**Interface:** USB 3.0 5 Gbps; total USB Accelerator performance varies with host CPU and USB speed. For tiny models the USB transfer is not the bottleneck; model load into the 8 MB SRAM takes up to ~16 ms worst case (8 MB at USB 3.0 speeds). [Medium teardown 2019; coral.ai benchmarks preamble]
