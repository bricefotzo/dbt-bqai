{#-
  AI.CLASSIFY — classify an input into one of the categories you provide.

  Returns STRING (the single best category) by default, or ARRAY<STRING> when
  output_mode => 'multi'.

  Args:
    input             raw SQL expression to classify (required)
    categories        a list of labels (["a", "b"]) rendered as a BigQuery
                      array literal, or a raw SQL array expression as a string.
    output_mode       'single' (default) or 'multi'.
    examples          raw SQL ARRAY<STRUCT<STRING, STRING>> expression.
    embeddings        raw SQL expression enabling optimized mode.
    optimization_mode 'MINIMIZE_COST' (default) or 'MAXIMIZE_QUALITY'.
    max_error_ratio   FLOAT64 in [0, 1]. Not supported by BigQuery when the
                      optimized (embeddings) path is active, so the macro
                      suppresses it whenever `embeddings` is set.
    connection_id / endpoint
                      per-call overrides for the project vars.
-#}
{%- macro classify(input, categories, output_mode=none, connection_id=none, endpoint=none, examples=none, embeddings=none, optimization_mode=none, max_error_ratio=none) -%}
  {%- set mer = max_error_ratio if max_error_ratio is not none else var('bqai_max_error_ratio', none) -%}
AI.CLASSIFY({{ input }}, categories => {{ bqai._bqai_array(categories) }}
  {%- if examples is not none %}, examples => {{ examples }}{% endif -%}
  {{ bqai._bqai_managed_kwargs(connection_id, endpoint) }}
  {%- if output_mode is not none %}, output_mode => '{{ output_mode }}'{% endif -%}
  {%- if embeddings is not none %}, embeddings => {{ embeddings }}{% endif -%}
  {%- if optimization_mode is not none %}, optimization_mode => '{{ optimization_mode }}'{% endif -%}
  {%- if mer is not none and embeddings is none %}, max_error_ratio => {{ mer }}{% endif -%})
{%- endmacro -%}
