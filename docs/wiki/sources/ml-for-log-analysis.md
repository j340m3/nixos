# Source: Machine learning for automatic log analysis — approaches and model shapes

**URLs:**
- https://arxiv.org/html/2308.08736v3 — Wu, Li, Khomh, "On the Effectiveness of Log Representation for Log-based Anomaly Detection", arXiv:2308.08736v3 [cs.SE], 08 Apr 2024 (Polytechnique Montreal)
- https://pmc.ncbi.nlm.nih.gov/articles/PMC11330418/ — Khan, Shin, Bianculli, Briand, "Impact of log parsing on deep learning-based anomaly detection", Empirical Software Engineering 29(6):139, 17 Aug 2024 (open access, CC BY 4.0)
- https://developers.redhat.com/articles/2025/12/09/semantic-anomaly-detection-log-files-cordon — Red Hat Developer, "Semantic anomaly detection in log files with Cordon", 09 Dec 2025
- https://medium.com/snowflake/log-to-action-862e4a0da54d — Snowflake, "Log-to-Action" (template-ID + embedding anomaly detection at scale; LogBERT, DeepTempo)
**Accessed:** 2026-11-04

## Key extracts

**What automatic log analysis does with ML:** anomaly detection is the most widely studied task (also failure diagnosis, performance regression analysis, predictive/causal analysis). Core method: **log representation** — converting semi-structured textual logs into numerical feature vectors — then a downstream model. [arxiv 2308.08736, §1, §2]

**Typical pipeline:** raw logs → (usually) **log parsing / template identification** (Drain, Spell, AEL, IPLoM, ...) → structured templates → representation → model → anomaly/normal classification. Some recent methods skip parsing (NeuralLog, BERT-based). [arxiv 2308.08736 §2.1, §4.1; Khan et al. 2024 §2]

**Representation shapes (all numeric vectors fed to host-side models):**
- Log template ID / message count vector (count of occurrences per template; sequence-level)
- TF-IDF over templates or tokens (event- or sequence-level)
- Static embeddings: Word2Vec, FastText, Template2Vec (token/template-level)
- Contextual embeddings: BERT (768-d sentence embedding), used directly on raw log messages (NeuralLog)
- Graph-based: GNN over log sequences (less common)
[arxiv 2308.08736 §3.1–3.3]

**Downstream models actually used:** traditional — SVM, decision tree, logistic regression, random forest (on event-count vectors). Deep — MLP, CNN (Lu et al. 2018), LSTM/DeepLog, LogAnomaly, LogRobust, PLELog (GRU), Transformers/Logsy. All seven in Khan et al. 2024 require log parsing first; supervised models generally outperform unsupervised and are more stable. [arxiv 2308.08736 §3.4, §4.3; Khan et al. 2024 § experimental design]

**Key practical finding:** parsing accuracy does **not** strongly correlate with anomaly detection accuracy; template **distinguishability** (normal vs abnormal sequences remain separable after parsing) is what matters. [Khan et al. 2024 abstract & §6]

**Industry pattern:** anomaly detection on log **template IDs** plus embeddings, scored with cosine distance / k-NN density over embedding windows (e.g., all-MiniLM-L6-v2, 256-token max, ~4-line windows). [Red Hat Cordon 2025-12-09; Snowflake Medium]

**Datasets:** LogHub HDFS, BGL, Spirit, Thunderbird; experiments on HPC-class hosts (dual Xeon Skylake, 64 GB RAM) — i.e., the ML itself runs on host CPUs, not on an accelerator. [arxiv 2308.08736 §4.3.2; Khan et al. 2024]

## Relevance to Coral

Log-analysis models are **tabular/time-series/embedding models** (count vectors, TF-IDF, LSTM, BERT), not the quantized CNNs (MobileNet, EfficientDet, SSD) the Edge TPU was built for. The Edge TPU op list covers Conv2d/DepthwiseConv2d/Pool/Softmax and a unidirectional LSTM (runtime ≥14) — nothing for BERT/Transformer self-attention, and MLP/fully-connected only in limited form. Feature extraction (parsing, tokenization, embedding generation) runs on the host CPU; only the final inference kernel could be offloaded to the TPU, and only if it compiles (100% op coverage needed, else order-of-magnitude slowdown). [models-intro op table; this page]
