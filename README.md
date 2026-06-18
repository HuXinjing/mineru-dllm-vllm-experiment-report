# MinerU-DLLM vLLM Experiment Report

This repository packages the experiment notes, rerun artifacts, and code needed
to reproduce the MinerU-Diffusion vLLM integration measurements.

## Repository Contents

- `reports/`: curated markdown summaries from the original investigation and
  the rerun on cleaned PR repositories.
- `data/original/`: selected original summary JSON/JSONL files and Pareto plots.
- `data/rerun/curated_20260618_pr_repos/`: fresh rerun artifacts produced from
  the cleaned vLLM PR repository and cleaned MinerU benchmark harness repository.
- `manifests/pdf_suite_coverage/`: the 23-page PDF coverage manifest and page
  images used for the experiments.
- `code/mineru_diffusion_harness/`: benchmark harness code snapshot.
- `code/vllm_mineru_diffusion/`: key vLLM MinerU-Diffusion model/config code
  snapshot.
- `patches/`: patch files for the two upstream PR preparation branches.
- `scripts/`: scripts used to start the vLLM server and rerun curated
  experiments.
- `data/rerun/curated_20260618_pr_repos/environment_20260618.json`:
  GPU, OS, Python/package, and vLLM runtime metadata captured for the cleaned
  rerun.

## Cleaned PR Inputs

The rerun used these PR-preparation repositories. Public artifacts use
placeholder paths instead of machine-local absolute paths:

| Component | Path placeholder | Commit |
|---|---|---|
| vLLM MinerU-Diffusion integration | `<VLLM_PR_REPO>` | `7f6e10e357a46f05572184b53745bf457ccf09e9` |
| MinerU benchmark harness | `<MINERU_HARNESS_PR_REPO>` | `b88a65d893b6da86f29fadcec88960e2b0956cda` |

## Main Rerun Result

See `reports/rerun_curated_20260618.md`.

Short version: the cleaned PR repositories reproduce the earlier conclusion.
MinerU-DLLM text/table markdown remains close to the MinerU2.5-Pro reference,
but the full two-step run is not faster than the Pro baseline in this harness.
Layout sampling changes reduce layout wall time modestly, not enough to explain
the larger performance gap.

## Environment Summary

The cleaned rerun used one visible GPU: `CUDA_VISIBLE_DEVICES=0` on an
NVIDIA GeForce RTX 4090 24GB. The host had two RTX 4090 cards, but the vLLM
server was started against GPU 0 only.

| Item | Value |
|---|---|
| OS | Ubuntu 22.04.5 LTS, Linux 5.15.0-181-generic x86_64 |
| GPU used | NVIDIA GeForce RTX 4090, 24564 MiB, UUID `GPU-263675c4-449e-e97c-50e9-60e8a427c254` |
| Other GPU present | NVIDIA GeForce RTX 4090, 24564 MiB, UUID `GPU-6b7b5248-c07b-239a-e00d-fbc55798d7c7` |
| Driver / CUDA shown by nvidia-smi | 580.126.09 / 13.0 |
| Python | 3.12.11, `<PYTHON_BIN>` |
| PyTorch / CUDA runtime | `torch==2.11.0+cu128`, `torch.version.cuda==12.8` |
| Key packages | `vllm==0.1.dev17674+gec36b4a1c.precompiled`, `transformers==5.12.1`, `triton==3.6.0`, `flashinfer-python==0.6.12` |

The vLLM server logs show `Using V2 Model Runner`, `TRITON_ATTN`,
`dtype=bfloat16`, `max_model_len=4096`, `max_num_seqs=4`,
`max_num_batched_tokens=4096`, prefix caching enabled, chunked prefill enabled,
and CUDA graph capture in `FULL_AND_PIECEWISE` mode.

## Reproduce

Set the local paths and run:

```bash
VLLM_REPO=/path/to/vllm-mineru-diffusion-pr \
MINERU_REPO=/path/to/mineru-dllm-harness-pr \
MODEL_PATH=/path/to/MinerU-Diffusion-V1-0320-2.5B \
PYTHON_BIN=/path/to/python \
GPU=0 \
FLASH_ATTN_EXT_SOURCE=/path/to/vllm/vllm_flash_attn \
./scripts/run_curated_rerun.sh
```

`FLASH_ATTN_EXT_SOURCE` is only needed when the vLLM source worktree does not
contain the locally built `vllm_flash_attn` extension binaries.
