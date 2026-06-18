# MinerU-DLLM Internal Denoising Loop Experiment

Date: 2026-06-17

## Change

Added an opt-in runner/model-state hook behind
`VLLM_MINERU_DIFFUSION_INTERNAL_DENOISE=1`.

The hook lets MinerU-Diffusion run repeated
`sample -> refresh canvas input ids/embeds -> forward` steps inside one v2
runner sampling turn, then returns when a canvas commit is produced. The default
path is unchanged when the env flag is unset.

## Results

Same 23-page manifest and throughput settings as the prior ablation:
`dynamic_threshold=0.80`, `layout_concurrency=2`, `content_concurrency=2`,
TRITON attention, v2 runner, single GPU.

| Variant | Wall s | Pages/s | Markdown chars | Speed vs baseline | Mean markdown sim vs baseline | Mean layout F1 vs baseline |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| baseline | 86.759 | 0.265 | 140055 | 1.00x | 1.000 | 1.000 |
| mask_only | 84.314 | 0.273 | 146402 | 1.03x | 0.998 | 0.997 |
| internal_loop | 128.065 | 0.180 | 67053 | 0.68x | 0.930 | 0.937 |

2-page smoke:

| Variant | Wall s | Pages/s | Markdown chars |
| --- | ---: | ---: | ---: |
| baseline | 8.414 | 0.238 | 7250 |
| mask_only | 7.135 | 0.280 | 7250 |
| internal_loop | 14.637 | 0.137 | 7250 |

## Main Regression

`mineru_diffusion_paper_p0033` regressed like the earlier `steps16` run:

| Case | Baseline chars | Internal-loop chars | Markdown similarity | Layout F1 |
| --- | ---: | ---: | ---: | ---: |
| `mineru_diffusion_paper_p0033` | 72502 | 590 | 0.015 | 0.429 |

Most other pages kept similar length and high similarity, but this long
formula/table example makes the candidate unusable as a quality-preserving
optimization.

## Interpretation

The hook does reduce scheduler-visible denoising iterations. Runtime logs showed
mean denoising steps per canvas around 1.6-1.8 during the run.

However, the inner forward currently bypasses vLLM's captured/compiled
PIECEWISE/FULL graph path and runs raw eager forwards with
`CUDAGraphMode.NONE`. That cost is larger than the scheduler round-trip saved,
so wall time regresses.

Quality also regresses on a long page. This means the current high-level hook is
not a viable optimization path. A useful version would need the inner loop to
live below the graph/runner dispatch layer, reusing the same fast forward path
instead of re-entering raw model execution from `sample_tokens()`.

## Artifacts

- Smoke results: `smoke_internal/latest_results.jsonl`,
  `smoke_internal/latest_summary.json`
- 23-page results: `internal_23pages/latest_results.jsonl`,
  `internal_23pages/latest_summary.json`
- Comparisons: `compare_internal_vs_baseline.json`,
  `compare_internal_vs_mask_only.json`
- Server log: `internal_server.log`
