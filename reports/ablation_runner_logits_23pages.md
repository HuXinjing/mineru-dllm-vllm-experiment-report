# MinerU-DLLM Runner Logits Compaction Ablation

Date: 2026-06-17

Input: `benchmark_results/mineru_diffusion/pdf_suite_coverage/manifest.json`

Config: 23 pages, `dynamic_threshold=0.80`, `layout_concurrency=2`, `content_concurrency=2`, TRITON attention, v2 model runner, single GPU.

Change under test: `VLLM_MINERU_DIFFUSION_MASK_ONLY_SAMPLING=1` now compacts sampling hidden states before `compute_logits`, so only still-masked canvas rows compute vocab logits. The sampler then scatters compact rows back by original logits row index.

| Variant | Runner logits compaction | Max denoising steps | Wall s | Pages/s | Speedup vs baseline | Markdown sim vs baseline | Layout F1 vs baseline | Markdown chars |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| baseline | off | 32 | 86.759 | 0.265 | 1.00x | 1.000 | 1.000 | 140055 |
| steps16 | off | 16 | 65.476 | 0.351 | 1.33x | 0.928 exact | 0.930 | 66796 |
| mask_only | on | 32 | 84.314 | 0.273 | 1.03x | 0.998 exact on 22/23; 0.999 token cosine all | 0.997 | 146402 |
| mask_steps16 | on | 16 | 61.019 | 0.377 | 1.42x | 0.925 exact | 0.925 | 67535 |

Additional pair:

| Pair | Wall speedup | Markdown sim | Layout F1 | Note |
| --- | ---: | ---: | ---: | --- |
| mask_steps16 vs steps16 | 1.07x | 0.965 exact | 0.951 | Not identical after runner-level compaction |

Outliers:

| Case | Baseline chars | steps16 chars | mask_only chars | mask_steps16 chars | Observation |
| --- | ---: | ---: | ---: | ---: | --- |
| `mineru_diffusion_paper_p0033` | 72486 | 494 | 78839 | 547 | `max_denoising_steps=16` collapses this long page; mask_only stays content-similar to baseline |

Notes:

- The old 2-page run made `steps16` and `mask_steps16` look identical. On 23 pages with runner-level logits compaction, they are no longer identical: `mask_steps16` is 1.07x faster than `steps16`, with markdown similarity 0.965 between the two.
- The quality-preserving optimization is `mask_only`: it improves end-to-end wall time only 2.9% while preserving output closely. Exact markdown similarity was computed on 22 pages; the skipped page is the 72k/79k-char long page where standard-library `SequenceMatcher(autojunk=False)` is too slow. Its token cosine is 0.994 and layout F1 is 0.973.
- Most of the speed gain still comes from reducing denoising steps, but that hurts quality on long/complex pages. `steps16` and `mask_steps16` both roughly halve markdown chars because of `mineru_diffusion_paper_p0033`.
- This confirms logits compaction is real but not a large end-to-end win. The remaining wall time is dominated by model forward, vision/MM work, request scheduling, and Python/layout/content orchestration, not just vocab logits/softmax.

Artifacts:

- `baseline/latest_results.jsonl`, `baseline/latest_summary.json`
- `steps16/latest_results.jsonl`, `steps16/latest_summary.json`
- `mask_only/latest_results.jsonl`, `mask_only/latest_summary.json`
- `mask_steps16/latest_results.jsonl`, `mask_steps16/latest_summary.json`
- `compare_steps16.json`
- `compare_mask_steps16.json`
- `compare_steps16_vs_mask_steps16.json`
- `fast_compare_summary.json`
