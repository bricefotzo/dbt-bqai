# Changelog

All notable changes to this project will be documented in this file. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-07-25

### Added

Initial release. Scalar macros wrapping the BigQuery AI.* function family:

- `bqai.generate` / `generate_bool` / `generate_int` / `generate_double` — wrap
  `AI.GENERATE` and the typed `AI.GENERATE_*` functions. Extract `.result` by
  default (`extract=false` keeps the full struct); `generate` supports
  `output_schema` for structured output.
- `bqai.classify` — wraps `AI.CLASSIFY`, with list-or-raw `categories`,
  `output_mode`, and the optimized-mode arguments (`examples`, `embeddings`,
  `optimization_mode`). Includes compile-time parameter validation.
- `bqai.score` — wraps `AI.SCORE`.
- `bqai.ai_if` — wraps `AI.IF` (named `ai_if` because `if` is a reserved Jinja
  keyword). Includes compile-time parameter validation.
- `bqai.embed` — wraps `AI.EMBED`, defaulting the model from
  `bqai_embedding_endpoint`.
- Generic dbt data tests: `bqai.assert_valid_category` and `bqai.assert_embedding_dimension`
  for validating AI outputs in `schema.yml`.

Configuration is resolved from `bqai_*` project vars with per-call keyword
overrides. `model_params` is emitted as a JSON-typed literal. Includes an
offline render test suite (`tests/render_test.py`), `uv`-accelerated CI workflows, and a runnable
`integration_tests/` dbt project.

