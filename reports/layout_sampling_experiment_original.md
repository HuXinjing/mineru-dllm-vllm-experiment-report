# DLLM Layout Sampling Experiment

Scope: layout-only requests on the 23-page PDF coverage suite.

Run metadata:

- Model: `<MODEL_PATH>/MinerU-Diffusion-V1-0320-2.5B`
- Endpoint: vLLM OpenAI API on `127.0.0.1:18088`, stopped after the run.
- Runner evidence: server log showed `Using V2 Model Runner` and CUDA graph capture for PIECEWISE/FULL.
- Threshold: `dynamic_threshold=0.90`, `block_size=32`, `layout_concurrency=4`.
- Image path: both DLLM variants used pre-encoded `data:image/png;base64,...` layout images to keep the request path identical.
- Timing note: layout-only `layout_elapsed` is request round-trip time per page and includes queueing under concurrency. Prefer same-run `Wall s` when comparing variants in this experiment.

| Variant | OK | Layout total s | Wall s | Mean s | Layout chars | Blocks | Chars/layout-s |
|---|---:|---:|---:|---:|---:|---:|---:|
| DLLM default temp=1 | 23/23 | 52.231 | 13.934 | 2.271 | 28136 | 341 | 538.7 |
| DLLM MinerU layout sampling | 23/23 | 48.108 | 12.369 | 2.092 | 28566 | 346 | 593.8 |
| MinerU2.5-Pro existing layout | 23/23 | 26.551 | n/a | 1.154 | 27895 | 338 | 1050.6 |

## Default vs MinerU Layout Sampling

- Total layout speedup: 1.0857x (default / MinerU-sampling).
- Wall-time speedup: 1.1265x (13.934s / 12.369s).
- Mean layout F1 between variants: 0.9582.

## Existing Pro Layout Reference

- Pro / DLLM default layout speedup: 0.5083x.
- Pro / DLLM MinerU-sampling layout speedup: 0.5519x.
- Pro vs DLLM MinerU-sampling mean layout F1: 0.8748.

Interpretation:

- Matching official MinerU layout sampling helps, but only modestly: about 8.6% by summed request latency and 12.6% by same-run wall time.
- It does not explain the whole Pro-vs-DLLM layout gap. Even after this change, DLLM layout remains much slower than the existing Pro layout reference on this suite.
- The dominant remaining gap is still the DLLM layout generation path itself: multiple denoise forwards per 32-token canvas for a short structured layout sequence.
