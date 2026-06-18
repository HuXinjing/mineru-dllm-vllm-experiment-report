# Pro conc4 vs DLLM conc4

Baseline: `pdf_suite_mineru25pro_vllm_http_conc4_tied`, 23/23 ok, total latency 70.782s, mean latency 3.077s, markdown chars 76331.

| DLLM threshold | Pro total s | DLLM total s | Pro/DLLM speedup | DLLM latency delta | Markdown sim | Layout F1 |
|---:|---:|---:|---:|---:|---:|---:|
| 0.80 | 70.782 | 73.345 | 0.965x | +3.6% | 0.8735 | 0.8785 |
| 0.85 | 70.782 | 76.244 | 0.928x | +7.7% | 0.8800 | 0.8519 |
| 0.90 | 70.782 | 71.843 | 0.985x | +1.5% | 0.8750 | 0.8647 |
| 0.95 | 70.782 | 84.250 | 0.840x | +19.0% | 0.8757 | 0.8583 |

Note: `Pro/DLLM speedup` is `Pro total latency / DLLM total latency`; values below 1 mean DLLM is slower than Pro.
