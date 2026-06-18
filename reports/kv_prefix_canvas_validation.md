# MinerU-Diffusion KV Prefix / Canvas Validation

Run date: 2026-06-17

## Scope

Validated whether the current MinerU-Diffusion vLLM path:

- Reuses the fixed prompt/image prefix KV after prefill.
- Schedules/profiles only the current mutable canvas during denoising.
- Saves probability-threshold-accepted token results across denoise steps.
- Commits accepted tokens into the stable vLLM sequence/KV cache before or only at canvas commit.

## Artifacts

- Trace JSONL: `benchmark_results/mineru_diffusion/internal_profile/kv_prefix_canvas_trace.jsonl`
- Final 2-page run: `benchmark_results/mineru_diffusion/internal_profile/kv_prefix_canvas_run_final/`
- Server log: `benchmark_results/mineru_diffusion/internal_profile/kv_prefix_canvas_server.log`
- Manifest: `benchmark_results/mineru_diffusion/internal_profile/manifest_2pages.json`

## Runtime Setup

- Model: `<MODEL_PATH>/MinerU-Diffusion-V1-0320-2.5B`
- Endpoint: vLLM OpenAI server on port 18086
- Runner: V2 model runner
- Attention backend: `TRITON_ATTN`
- CUDA graph capture: active for PIECEWISE and FULL modes
- Threshold: `dynamic_threshold=0.80`
- Layout/content concurrency: 2 / 2

The initial FlashAttention attempt failed because local FA2 does not support this per-sequence causal path. The validated run used `--attention-backend TRITON_ATTN`.

## Run Summary

```json
{
  "num_cases": 2,
  "num_ok": 2,
  "num_failed": 0,
  "throughput_wall_elapsed_s": 8.734580853953958,
  "throughput_layout_wall_elapsed_s": 3.157160866074264,
  "throughput_extract_wall_elapsed_s": 5.57741600391455,
  "throughput_pages_per_s": 0.2289749254647569,
  "markdown_chars": 7250
}
```

## Trace Summary

- Total trace records: 394
- Prefill records: 12
- Denoise records: 382
- Denoise request rows: 567
- Non-commit denoise rows: 467
- Commit rows: 100

Validated invariants from the final trace:

| Check | Result |
| --- | --- |
| `num_scheduled_tokens == num_draft_tokens_per_req == valid_len` for denoise rows | pass |
| `num_computed_prefill_tokens_np >= prefill_len_np` for denoise rows | pass |
| non-commit rows have `num_sampled=0` and `num_rejected=valid_len` | pass |
| commit rows have `num_sampled=valid_len` and `num_rejected=0` | pass |

Representative first request:

| Phase | scheduled | computed prefill / prefill | positions | sampled / rejected | mask before -> after |
| --- | ---: | ---: | --- | ---: | ---: |
| prefill | 1389 | 0 / 1389 | 0..1388 | 0 / 0 | n/a |
| denoise step 0 | 32 | 1389 / 1389 | 1389..1420 | 0 / 32 | 32 -> 14 |
| denoise step 1 | 32 | 1389 / 1389 | 1389..1420 | 0 / 32 | 14 -> 12 |
| denoise step 10 | 32 | 1389 / 1389 | 1389..1420 | 0 / 32 | 1 -> 0 |
| commit | 32 | 1389 / 1389 | 1389..1420 | 32 / 0 | 0 -> reset |
| next canvas | 32 | 1421 / 1421 | 1421..1452 | 0 / 32 | 32 -> 6 |

## Interpretation

1. Prefix KV is effective after prefill.

   The first layout request prefills 1389 tokens at positions 0..1388. All following denoise steps for that canvas schedule 32 tokens at positions 1389..1420 while `num_computed_prefill_tokens_np == prefill_len_np == 1389`. The prefix is not being re-run through the transformer layers on every denoise step.

2. The profiled denoise forward is the current canvas query span, not full prompt + canvas recomputation.

   For denoise rows, scheduled tokens, draft tokens, valid logits, and position span are all exactly the 32-token canvas. The forward still attends to cached prefix KV plus the current canvas segment, so it is not free of prefix-related attention reads, but it does not recompute prefix MLP/attention activations.

3. Accepted token values are saved as canvas state and reused in later denoise steps.

   Non-commit rows show mask counts decreasing across repeated forwards over the same position span, and `draft_tokens` is updated from `states.canvas` after each denoise step. This means threshold-accepted token ids are retained as token/canvas state.

4. Accepted token KVs are not committed as stable sequence KV until the canvas commit step.

   During intermediate denoise rows, `num_sampled=0` and `num_rejected=32`, so vLLM treats the scheduled canvas as non-committable draft tokens. Only the commit row emits `num_sampled=32` and `num_rejected=0`; after that, the next canvas advances from positions 1389..1420 to 1421..1452.

5. The CPU `num_computed_tokens_np` field is optimistic under async scheduling.

   It may show `prefill + 32` during intermediate denoise, but the actual `positions` remain on the same canvas span until commit. Use `position_ranges` and sampled/rejected together when interpreting this path.

## DiffusionGemma Comparison

DiffusionGemma follows the same broad model: it stores canvas-level token state (`canvas`, `argmax_canvas`, accepted history, self-conditioning embedding) and computes `num_rejected=query_len` for denoise steps where `num_sampled=0`. It does not maintain a per-layer KV cache for only the accepted subset of the current mutable canvas. It stores token/embedding state, not exact accepted-token KV across mutable bidirectional canvas steps.

## Optimization Implication

The current path has prefix KV cache, CUDA graph capture, and token-level canvas state reuse. The remaining repeated work is the current 32-token canvas forward each denoise step, including logits/softmax for the whole canvas. Exact KV reuse for only accepted positions inside the mutable canvas is not straightforward because MinerU-Diffusion uses bidirectional canvas attention: accepted positions can still change their hidden states when remaining mask positions change. A correct optimization would need either a specialized masked-position-only algorithm with careful dependency handling, or an approximate KV reuse strategy with quality validation.
