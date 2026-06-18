# Curated Rerun on Clean PR Repositories

Date: 2026-06-18

## Inputs

| Component | Commit |
|---|---|
| vLLM MinerU-Diffusion PR prep | `7f6e10e357a46f05572184b53745bf457ccf09e9` |
| MinerU harness PR prep | `b88a65d893b6da86f29fadcec88960e2b0956cda` |

Model:

```text
<MODEL_PATH>/MinerU-Diffusion-V1-0320-2.5B
```

## Environment

Full machine/runtime metadata is stored in:

```text
data/rerun/curated_20260618_pr_repos/environment_20260618.json
```

Summary:

| Item | Value |
|---|---|
| Host OS | Ubuntu 22.04.5 LTS, Linux 5.15.0-181-generic x86_64 |
| GPU visible to benchmark | `CUDA_VISIBLE_DEVICES=0` |
| GPU used | NVIDIA GeForce RTX 4090, 24564 MiB, UUID `GPU-263675c4-449e-e97c-50e9-60e8a427c254` |
| Additional GPU present | NVIDIA GeForce RTX 4090, 24564 MiB, UUID `GPU-6b7b5248-c07b-239a-e00d-fbc55798d7c7` |
| NVIDIA driver / CUDA shown by nvidia-smi | 580.126.09 / 13.0 |
| Python | 3.12.11 from `<PYTHON_BIN>` |
| PyTorch | `2.11.0+cu128`, `torch.version.cuda=12.8`, cuDNN `91900` |
| Key packages | `vllm=0.1.dev17674+gec36b4a1c.precompiled`, `transformers=5.12.1`, `triton=3.6.0`, `flashinfer-python=0.6.12`, `openai=2.41.1` |

Runtime configuration from the vLLM server logs:

| Item | Value |
|---|---|
| Model runner | V2 Model Runner |
| Attention backend | `TRITON_ATTN` |
| dtype | `bfloat16` |
| TP / PP / DP | 1 / 1 / 1 |
| Max model len | 4096 |
| Max batched tokens / max seqs | 4096 / 4 |
| GPU memory utilization | 0.8 |
| Prefix caching / chunked prefill | enabled / enabled |
| CUDA graph mode | `FULL_AND_PIECEWISE` |

The vLLM PR worktree needed local ignored `vllm_flash_attn` extension binaries
copied from the built original worktree. This is a local build artifact issue,
not a source patch difference.

## Layout Sampling Rerun

Scope: layout-only requests over the 23-page coverage suite.

| Variant | OK | Layout total s | Wall s | Mean s | Layout chars | Blocks | Chars/layout-s |
|---|---:|---:|---:|---:|---:|---:|---:|
| DLLM default temp=1 | 23/23 | 53.288 | 14.176 | 2.317 | 28091 | 341 | 527.2 |
| DLLM MinerU layout sampling | 23/23 | 48.275 | 12.404 | 2.099 | 28572 | 346 | 591.9 |
| Original MinerU2.5-Pro reference | 23/23 | 26.551 | n/a | 1.154 | 27895 | 338 | 1050.6 |

Default vs MinerU-style sampling:

- Total layout speedup: `1.1038x`.
- Mean layout F1 between variants: `0.9586`.

Pro reference vs DLLM MinerU-style sampling:

- Pro / DLLM layout speedup: `0.5500x`; values below 1 mean DLLM is slower.
- Mean layout F1: `0.8702`.

Artifact:

```text
data/rerun/curated_20260618_pr_repos/layout_sampling_t090/
```

## Two-Step Rerun

This run uses the same per-page two-step harness style as the original
Pro-vs-DLLM table: layout first, then content extraction with
`content_concurrency=4`, `dynamic_threshold=0.90`.

| Run | OK | Total latency s | Mean s | Markdown chars | Markdown chars/s |
|---|---:|---:|---:|---:|---:|
| Original MinerU2.5-Pro baseline | 23/23 | 70.782 | 3.077 | 76331 | 1078.4 |
| Original DLLM t090 conc4 | 23/23 | 71.843 | 3.124 | 68192 | 949.2 |
| Rerun DLLM t090 conc4 | 23/23 | 76.150 | 3.311 | 70506 | 925.9 |

Rerun DLLM vs original Pro baseline:

- Total speed ratio, Pro/DLLM: `0.9295x`; DLLM is slower in this run.
- Mean markdown similarity: `0.8774`.
- Mean layout F1: `0.8583`.

Artifact:

```text
data/rerun/curated_20260618_pr_repos/dllm_conc4_t090/
data/rerun/curated_20260618_pr_repos/compare_pro_original_vs_dllm_rerun.json
```

## Throughput Mode Supplement

The cleaned harness can also run the whole 23-page batch in throughput mode.
This is useful for serving-capacity experiments, but should not be mixed with
the per-page total-latency table above.

| Run | OK | Wall s | Layout wall s | Extract wall s | Pages/s | Markdown chars/s |
|---|---:|---:|---:|---:|---:|---:|
| Rerun DLLM t090 throughput | 23/23 | 45.120 | 13.921 | 31.199 | 0.510 | 1491.2 |

Artifact:

```text
data/rerun/curated_20260618_pr_repos/dllm_conc4_t090_throughput/
```

## Interpretation

The cleaned PR repositories reproduce the original direction:

- Layout sampling parameters improve DLLM layout speed only modestly.
- DLLM two-step output remains markdown-similar to the Pro reference, but layout
  agreement is materially lower than markdown agreement.
- In this harness and model path, DLLM two-step does not show the advertised
  multi-x speedup over the MinerU2.5-Pro baseline.

The remaining suspected bottleneck is still the denoising canvas loop and layout
stage behavior, not PDF image rendering or result file I/O.
