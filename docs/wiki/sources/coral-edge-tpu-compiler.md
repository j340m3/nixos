# Source: Edge TPU compiler, model requirements, and Python inference API

**URLs:**
- https://coral.ai/docs/edgetpu/compiler/ (Edge TPU Compiler)
- https://coral.ai/docs/edgetpu/models-intro/ (TensorFlow models on the Edge TPU — model requirements, quantization, supported ops)
- https://coral.ai/docs/edgetpu/tflite-python/ (Run inference on the Edge TPU with Python / PyCoral)
- https://github.com/google-coral/pycoral (PyCoral repo)
**Accessed:** 2026-11-04
**Versions referenced:** Edge TPU Compiler 16.0 (requires Edge TPU runtime 14 by default); compiler/runtime version table also lists 2.1.302470888 → runtime 13, 2.0 → runtime 12, 1.0 → runtime 10. Coral docs copyright 2020 Google LLC; pages live on coral.ai as of 2026-11-04.

## Key extracts

**What the device runs:** "The Edge TPU supports only TensorFlow Lite models that are fully 8-bit quantized and then compiled specifically for the Edge TPU." Training cannot be done in TFLite; you train in TensorFlow (or PyTorch → ONNX → TF SavedModel → TFLite), convert to `.tflite`, quantize, then compile with `edgetpu_compiler`. [models-intro]

**Quantization paths:** quantization-aware training (TF1-era, recommended for accuracy) or full-integer post-training quantization requiring a **representative dataset** (same data range/style as training data). Converter flags: `Optimize.DEFAULT`, `supported_ops = TFLITE_BUILTINS_INT8`, `inference_input_type = tf.uint8`, `inference_output_type = tf.uint8`. Integer-only enforcement is possible; non-quantizable ops are left in float and are **not** Edge TPU-compatible. [models-intro; developers.google.com/edge/litert post-training quantization; github.com/google-coral/edgetpu#222]

**Model structural requirements:** tensor parameters quantized (int8/uint8); tensor sizes constant at compile-time (no dynamic shapes); parameters constant at compile-time; tensors 1–3-dimensional (only 3 innermost dims may exceed 1); only Edge TPU-supported operations. [models-intro, table 1]

**Supported operations (excerpt):** Add, AveragePool2d, Concatenation, Conv2d, DepthwiseConv2d, FullyConnected, LSTM (≥ runtime 14, unidirectional only), MaxPool2d, Mean, Mul, Pad, Pack, Quantize, ReduceMax/Min, ReLU/ReLU6/ReLUN1To1, Reshape, ResizeBilinear/NearestNeighbor, Rsqrt, Slice, Softmax (1-D input, ≤16,000 elements), SpaceToDepth, Split, Squeeze, StridedSlice, Sub, Sum, Tanh, Transpose (≥14), TransposeConv (≥13). Notably **no** generic dense NLP/Transformer op set beyond small LSTM; graphs are CNN-friendly. [models-intro, table 1]

**Compilation behaviour:** `edgetpu_compiler` partitions the graph at the **first unsupported operation**: everything before it becomes one custom Edge TPU op; that op and everything after runs on the CPU. The compiler cannot partition more than once. "If even a small fraction of your model executes on the CPU, it can potentially slow the inference speed by an order of magnitude." Compiler prints how many ops map to Edge TPU vs CPU. [models-intro]

**Compiler host requirements:** 64-bit Debian 6.0+ / Ubuntu 10.0+, **x86-64 only** (compiler no longer available for ARM64 since v2.1). Web compiler via Google Colab available. Output: `model_edgetpu.tflite` + `.log` operation report. Co-compilation shares the ~8 MB SRAM parameter cache across models; segmentation (`--num_segments`) and pipelining (`PipelinedModelRunner`) scale across multiple Edge TPUs. Rule of thumb: `num_segments = ceil(model size MB / 6 MB)`. [compiler]

**Edge TPU RAM:** ~8 MB SRAM total; ~6.91 MiB available for parameter caching on a single model; unfit parameters stream from external ("off-chip") memory at runtime, which is slower and makes the first inference slower (model load into TPU memory). [compiler, parameter-data-caching]

**Python inference:** standard TensorFlow Lite `Interpreter` + Edge TPU delegate (`libedgetpu.so.1` on Linux, `libedgetpu.1.dylib` macOS, `edgetpu.dll` Windows), or the PyCoral wrapper (`edgetpu.make_interpreter(...)`, `interpreter.allocate_tensors()`, `interpreter.invoke()`). PyCoral is a Debian package (`python3-pycoral`) or wheel; pip install not guaranteed compatible with apt-installed Coral libraries — version matching between libcoral/libedgetpu/pycoral is critical. [tflite-python; pycoral GitHub]

**On-device training:** only for image classification, last layer only — weight imprinting (1–200 samples/class, as few as 5) or backpropagation on the final fully-connected layer; requires specially structured models. No general on-device training; training happens off-device. [models-intro, transfer-learning on-device]
