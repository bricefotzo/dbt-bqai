# Changelog

## 0.1.0

Initial release. Scalar macros wrapping the BigQuery AI.* function family:

- `bqai.generate` / `generate_bool` / `generate_int` / `generate_double` — wrap
  `AI.GENERATE` and the typed `AI.GENERATE_*` functions. Extract `.result` by
  default (`extract=false` keeps the full struct); `generate` supports
  `output_schema` for structured output.
- `bqai.classify` — wraps `AI.CLASSIFY`, with list-or-raw `categories`,
  `output_mode`, and the optimized-mode arguments (`examples`, `embeddings`,
  `optimization_mode`).
- `bqai.score` — wraps `AI.SCORE`.
- `bqai.ai_if` — wraps `AI.IF` (named `ai_if` because `if` is a reserved Jinja
  keyword).
- `bqai.embed` — wraps `AI.EMBED`, defaulting the model from
  `bqai_embedding_endpoint`.

Configuration is resolved from `bqai_*` project vars with per-call keyword
overrides. `model_params` is emitted as a JSON-typed literal. Includes an
offline render test suite (`tests/render_test.py`) and a runnable
`integration_tests/` dbt project.
