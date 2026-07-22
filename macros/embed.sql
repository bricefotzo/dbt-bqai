{#-
  AI.EMBED — generate an embedding vector for text content.
  Returns ARRAY<FLOAT64>.

  BigQuery requires either an `endpoint` or a `model` for AI.EMBED. This macro
  supplies the endpoint from `bqai_embedding_endpoint` (a separate var from the
  generation endpoint, since embedding models differ) and raises a compile
  error if none is resolved.

  Args:
    content        raw SQL expression for the text to embed (required)
    task_type      e.g. 'SEMANTIC_SIMILARITY', 'RETRIEVAL_DOCUMENT'.
    title          optional document title (used by some task types).
    model_params   JSON literal; only the `dimension` field is supported by
                   AI.EMBED. Passed as a JSON-typed literal. NOT defaulted from
                   `bqai_model_params` (that var holds generation config).
    connection_id / endpoint
                   per-call overrides. endpoint defaults from
                   `bqai_embedding_endpoint`.
-#}
{%- macro embed(content, task_type=none, title=none, connection_id=none, endpoint=none, model_params=none) -%}
  {%- set ep = endpoint if endpoint is not none else var('bqai_embedding_endpoint', none) -%}
  {%- set conn = connection_id if connection_id is not none else var('bqai_connection', none) -%}
  {%- if ep is none -%}
    {{ exceptions.raise_compiler_error("bqai.embed: no embedding endpoint resolved. Set the 'bqai_embedding_endpoint' var or pass endpoint=...") }}
  {%- endif -%}
AI.EMBED({{ content }}, endpoint => '{{ ep }}'
  {%- if task_type is not none %}, task_type => '{{ task_type }}'{% endif -%}
  {%- if title is not none %}, title => '{{ title }}'{% endif -%}
  {%- if model_params is not none %}, model_params => JSON '''{{ model_params }}'''{% endif -%}
  {%- if conn is not none %}, connection_id => '{{ conn }}'{% endif -%})
{%- endmacro -%}
