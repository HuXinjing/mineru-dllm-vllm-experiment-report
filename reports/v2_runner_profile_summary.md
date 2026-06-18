# V2 Runner Internal Profile Summary

Question: whether the slow MinerU-DLLM result is because V2 runner was not used, and where the V2 runner time goes.

Evidence:
- Server startup logged `Using V2 Model Runner` for MinerU-Diffusion.
- Startup also logged CUDA graph capture for PIECEWISE and FULL modes.
- Startup warned that `torch.compile` is enabled but this MinerU-Diffusion model does not support it.
- Initial vLLM built-in profiling did not show V2 runner phase scopes because the V2 runner path had no equivalent scope labels; I added env-gated `v2_gpu_model_runner:*` profiling scopes.

Profile run:
- Manifest: `benchmark_results/mineru_diffusion/internal_profile/manifest_2pages.json`.
- Endpoint mode: DLLM t=0.80, layout/content concurrency 2.
- Trace dir: `benchmark_results/mineru_diffusion/internal_profile/dllm_t080_v2scopes_trace/`.
- Profiler config: torch profiler, `VLLM_CUSTOM_SCOPES_FOR_PROFILING=1`, frontend ignored, max 100 worker steps.
- Caveat: this is a profiler sample, not a latency benchmark. It captured the early worker steps, mostly the layout phase.

| Scope / Event | Self CUDA | CUDA % | Calls | Avg CUDA |
| --- | ---: | ---: | ---: | ---: |
| `v2_gpu_model_runner: forward` | 899.877 ms | 76.93% | 100 | 8.999 ms |
| `v2_gpu_model_runner: mm_embeddings` | 475.676 ms | 40.67% | 101 | 4.710 ms |
| `v2_gpu_model_runner: sample_logits` | 379.738 ms | 32.46% | 100 | 3.797 ms |
| `v2_gpu_model_runner: prepare_inputs` | 59.226 ms | 5.06% | 100 | 0.592 ms |
| `v2_gpu_model_runner: state_update` | 9.512 ms | 0.81% | 20 | 0.476 ms |
| `v2_gpu_model_runner: prepare_attn` | 8.362 ms | 0.71% | 100 | 0.084 ms |
| `v2_gpu_model_runner: async_output` | 5.018 ms | 0.43% | 100 | 0.050 ms |
| `_gumbel_sample_kernel` | 4.573 ms | 0.39% | 99 | 0.046 ms |
| `Runtime Triggered Module Loading` | 14.096 ms | 1.21% | 20 | 0.705 ms |

Interpretation:
- This is not a simple “we accidentally used runner v1” issue; V2 runner is active.
- Scheduler/state/preparation overhead is small in this sample. The dominant cost is model work: repeated forward, multimodal embedding, and logits/sampling.
- CUDA graph capture is active, but torch.compile is not applied to this model, so one important vLLM V2 optimization path is missing.
- The profiler also caught first-inference Triton JIT for `_gumbel_sample_kernel`; this is a warmup gap, but its steady-state CUDA share is tiny in this sample.
