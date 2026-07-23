# dbt-bqai

dbt macros that wrap the BigQuery **AI.\*** function family so you can call generative AI, semantic
classification, scoring, filtering, and embeddings from your dbt models — without repeating the
connection, endpoint, and model-parameter boilerplate on every call.

You configure your connection and default model **once** in `dbt_project.yml`. Every macro resolves
them for you. Override per call when you need to.

```sql
-- models/enriched_reviews.sql
select
    review_id,
    review,
    {{ bqai.classify("review", ["positive", "neutral", "negative"]) }} as sentiment,
    {{ bqai.score("('Rate how positive this review is, 1-10: ', review)") }} as positivity
from {{ ref('stg_reviews') }}
where {{ bqai.ai_if("('This review mentions the product price: ', review)") }}
```

## Why

The BigQuery AI functions are powerful, but every call needs the same `connection_id`, `endpoint`,
and (often) `model_params` repeated inline. That boilerplate spreads across every model, drifts out
of sync, and makes cost controls (like a `thinking_budget` of 0) easy to forget. `dbt-bqai`
centralizes that config and gives you a clean, consistent macro surface.

## Requirements

- dbt >= 1.7.0 with the BigQuery adapter
- A BigQuery [Cloud resource connection](https://cloud.google.com/bigquery/docs/generate-text-tutorial)
  whose service account has the `Vertex AI User` role. (`connection_id` is optional on most of these
  functions — if you omit it they run with your end-user credentials — but a service-account
  connection is recommended for scheduled runs.)
- The AI functions used here (`AI.GENERATE`, `AI.GENERATE_BOOL/INT/DOUBLE`, `AI.IF`, `AI.CLASSIFY`,
  `AI.SCORE`, `AI.EMBED`). `AI.GENERATE` reached GA in January 2026; the managed functions
  (`AI.CLASSIFY`/`AI.SCORE`/`AI.IF`) and `AI.EMBED` rolled out around the same window. Check
  availability in your region before relying on them.

## Install

Add to your `packages.yml`:

```yaml
packages:
  - git: "https://github.com/bricefotzo/dbt-bqai.git"
    revision: 0.1.0
```

Then `dbt deps`. (A dbt Hub entry will follow once the package stabilizes.)


## Prerequisites: set up a BigQuery connection

BigQuery AI functions don't call Vertex AI directly with your
credentials. They go through a **Cloud resource connection**: a
BigQuery-managed service account that acts as the bridge between
your SQL queries and Vertex AI models. No connection (or a
misconfigured one) means every `AI.*` call fails.

You only need to do this once per project. Three steps:

**1. Create the connection**

> ⚠️ The connection MUST be in the same location as your BigQuery
> datasets. A `us` connection with an `EU` dataset fails with a
> `Not found: Connection` error. This is the #1 setup mistake.

```bash
bq mk --connection \
  --location=EU \
  --connection_type=CLOUD_RESOURCE \
  bqai-connection
```

**2. Get the connection's service account**

```bash
bq show --connection PROJECT.EU.bqai-connection
```

Copy the `serviceAccountId` from the output
(it looks like `bqcx-...@gcp-sa-bigquery-condel.iam.gserviceaccount.com`).

**3. Grant it access to Vertex AI**

```bash
gcloud projects add-iam-policy-binding PROJECT \
  --member="serviceAccount:SERVICE_ACCOUNT_ID" \
  --role="roles/aiplatform.user"
```

IAM propagation can take 1-2 minutes. If your first query fails
with a permission error right after this step, wait and retry.

Then reference it in `dbt_project.yml` as
`PROJECT.LOCATION.CONNECTION_ID`, e.g. `my-project.eu.bqai-connection`.


## Configure once

In the **consuming project's** `dbt_project.yml`:

```yaml
vars:
  bqai_connection: 'my-project.us.my-connection'   # PROJECT.LOCATION.CONNECTION_ID
  bqai_endpoint: 'gemini-2.5-flash'                # default model for generation + managed functions
  bqai_embedding_endpoint: 'text-embedding-005'    # default model for AI.EMBED
  # optional:
  bqai_model_params: '{"generation_config":{"thinking_config":{"thinking_budget":0}}}'
  bqai_max_error_ratio: 0.2                         # fail fast if >20% of rows error (managed fns)
```

All settings are optional. If you omit `bqai_connection`, queries fall back to your end-user
credentials. If you omit an endpoint, BigQuery picks a default model. `bqai_model_params` is a
**JSON string**; the macros emit it as a JSON-typed literal (`model_params => JSON '...'`), which is
what the AI functions expect.

Every setting can be overridden per call — pass `connection_id=`, `endpoint=`, `model_params=`, etc.
as keyword arguments to any macro.

## Macros

### General-purpose (you control the model and prompt)

| Macro | Wraps | Returns |
|---|---|---|
| `bqai.generate(prompt, output_schema=…)` | `AI.GENERATE` | `STRING` (or your struct schema) |
| `bqai.generate_bool(prompt)` | `AI.GENERATE_BOOL` | `BOOL` |
| `bqai.generate_int(prompt)` | `AI.GENERATE_INT` | `INT64` |
| `bqai.generate_double(prompt)` | `AI.GENERATE_DOUBLE` | `FLOAT64` |

`prompt` is a **raw SQL expression** (a column, a `CONCAT(...)`, or a `(string, column)` tuple), not a
quoted literal. By default the macros extract the `.result` field; pass `extract=false` to keep the
full `STRUCT<result, full_response, status>`.

```sql
select
    {{ bqai.generate("CONCAT('Summarize in one line: ', body)") }} as summary,
    {{ bqai.generate_bool("('Is this email a complaint? ', body)") }} as is_complaint
from {{ ref('stg_emails') }}
```

**Structured output.** Pass `output_schema` as a bare column-definition string (no outer quotes — the
macro adds them). When `output_schema` is set, `AI.GENERATE` returns a `STRUCT` whose fields are your
columns (plus `full_response` and `status`); there is no `.result` field, so the macro returns the
full struct for you to splat:

```sql
select
    complaint_id,
    {{ bqai.generate(
        "CONCAT('Analyze: ', narrative)",
        output_schema="complaint_type STRING, severity INT64"
    ) }}.* except (full_response, status)
from {{ ref('stg_complaints') }}
```

### Managed (BigQuery picks and tunes the model — start here)

| Macro | Wraps | Returns |
|---|---|---|
| `bqai.classify(input, categories)` | `AI.CLASSIFY` | `STRING` (or `ARRAY<STRING>` with `output_mode="multi"`) |
| `bqai.score(prompt)` | `AI.SCORE` | `FLOAT64` |
| `bqai.ai_if(prompt)` | `AI.IF` | `BOOL` (use in `WHERE`/`JOIN`) |

`categories` accepts a Python list (`["a", "b"]`, rendered as a BigQuery array literal with quotes
escaped) or a raw SQL array expression passed as a string. `ai_if` is named that way because `if` is a
reserved Jinja keyword.

These functions let BigQuery manage model selection, but they still accept an `endpoint`, so the
macros default it from `bqai_endpoint` (override per call). All three accept `max_error_ratio`
(defaulted from `bqai_max_error_ratio`). `classify` also takes `output_mode` (`"single"` default or
`"multi"`); `classify` and `ai_if` additionally accept `examples`, `embeddings`, and
`optimization_mode` for the optimized/distilled path. When you pass `embeddings`, the macro omits
`max_error_ratio` (BigQuery doesn't allow it on the optimized path).

```sql
select
    article_id,
    {{ bqai.classify("body", ["tech", "sport", "business", "politics"]) }} as topic
from {{ ref('stg_articles') }}
order by {{ bqai.score("('Newsworthiness 1-10: ', body)") }} desc
```

### Embeddings

| Macro | Wraps | Returns |
|---|---|---|
| `bqai.embed(content, task_type=…)` | `AI.EMBED` | `ARRAY<FLOAT64>` |

`AI.EMBED` requires an embedding model, so the macro supplies `endpoint` from
`bqai_embedding_endpoint` (a separate var, since embedding models differ from generation models) and
raises a compile error if none is set. `model_params` here is **not** defaulted from
`bqai_model_params`; for embeddings only the `dimension` field is supported, so pass it explicitly if
you need it.

```sql
select
    doc_id,
    {{ bqai.embed("body", task_type="SEMANTIC_SIMILARITY") }} as embedding
from {{ ref('stg_docs') }}
```

## Cost note

Every AI function call incurs Vertex AI charges per row. To control cost: materialize inputs before
calling, prefer managed functions (they optimize model selection), set a `thinking_budget` of 0 via
`bqai_model_params` for tasks that don't need reasoning, and consider the optimized/`embeddings` mode
for `AI.IF`/`AI.CLASSIFY` on large tables. See
[Optimize AI function costs](https://cloud.google.com/bigquery/docs/optimize-ai-functions).

## Development

The macros are validated by an offline render test that mimics dbt's Jinja environment and asserts on
the generated SQL — no BigQuery connection required:

```bash
pip install jinja2
python3 tests/render_test.py
```

`integration_tests/` is a runnable dbt project (example models under `integration_tests/models/`) that
exercises every macro against a real BigQuery project. Point the `bqai_integration_tests` profile at
your project, set the `bqai_*` vars, then `dbt deps && dbt build`.

## Roadmap

- **0.1** — scalar functions: `generate*`, `classify`, `score`, `ai_if`, `embed` (this release)
- **0.2** — table-valued helpers: `AI.GENERATE_TABLE`, `AI.GENERATE_EMBEDDING`, `VECTOR_SEARCH`
- **0.3** — fuzzy-matching / entity-resolution patterns (Levenshtein → vector search migration)
- **0.4** — cost & quality observability macros (token counting, eval scaffolding)

## License

Apache 2.0. See [LICENSE](./LICENSE).
