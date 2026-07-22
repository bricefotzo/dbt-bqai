{#-
  AI.IF — evaluate a natural-language condition, returning BOOL. Use it in
  WHERE / JOIN / CASE.

  Named `ai_if` because `if` is a reserved keyword in Jinja and cannot be a
  macro name.

  Args:
    prompt            raw SQL expression, typically a (string, column) tuple
                      such as "('This review mentions price: ', review)"
                      (required)
    examples          raw SQL ARRAY<STRUCT<STRING, BOOL>> expression.
    embeddings        raw SQL expression enabling optimized mode.
    optimization_mode 'MINIMIZE_COST' (default) or 'MAXIMIZE_QUALITY'.
    max_error_ratio   FLOAT64 in [0, 1]; defaults from `bqai_max_error_ratio`.
                      Suppressed when `embeddings` is set (optimized path).
    connection_id / endpoint
                      per-call overrides for the project vars.
-#}
{%- macro ai_if(prompt, connection_id=none, endpoint=none, examples=none, embeddings=none, optimization_mode=none, max_error_ratio=none) -%}
  {%- set mer = max_error_ratio if max_error_ratio is not none else var('bqai_max_error_ratio', none) -%}
AI.IF({{ prompt }}
  {%- if examples is not none %}, examples => {{ examples }}{% endif -%}
  {{ bqai._bqai_managed_kwargs(connection_id, endpoint) }}
  {%- if embeddings is not none %}, embeddings => {{ embeddings }}{% endif -%}
  {%- if optimization_mode is not none %}, optimization_mode => '{{ optimization_mode }}'{% endif -%}
  {%- if mer is not none and embeddings is none %}, max_error_ratio => {{ mer }}{% endif -%})
{%- endmacro -%}
