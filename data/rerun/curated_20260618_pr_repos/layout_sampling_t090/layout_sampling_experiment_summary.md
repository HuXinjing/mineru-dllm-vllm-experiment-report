# DLLM Layout Sampling Experiment

Scope: layout-only requests on the 23-page PDF coverage suite.

| Variant | OK | Layout total s | Wall s | Mean s | Layout chars | Blocks | Chars/layout-s |
|---|---:|---:|---:|---:|---:|---:|---:|
| DLLM default temp=1 | 23/23 | 53.288 | 14.176 | 2.317 | 28091 | 341 | 527.2 |
| DLLM MinerU layout sampling | 23/23 | 48.275 | 12.404 | 2.099 | 28572 | 346 | 591.9 |
| MinerU2.5-Pro existing layout | 23/23 | 26.551 | n/a | 1.154 | 27895 | 338 | 1050.6 |

## Default vs MinerU Layout Sampling

- Total layout speedup: 1.1038x (default / MinerU-sampling).
- Mean layout F1 between variants: 0.9586.

## Existing Pro Layout Reference

- Pro / DLLM default layout speedup: 0.4983x.
- Pro / DLLM MinerU-sampling layout speedup: 0.5500x.
- Pro vs DLLM MinerU-sampling mean layout F1: 0.8702.
