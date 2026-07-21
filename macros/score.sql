{#-
  AI.SCORE — score how well the data matches the instruction in the prompt.
  Returns FLOAT64. Handy in ORDER BY / thresholds.

  Args:
    prompt           raw SQL expression, typically a (string, column) tuple
                     such as "('Newsworthiness 1-10: ', body)" (required)
    max_error_ratio  FLOAT64 in [0, 1]; defaults from `bqai_max_error_ratio`.
    connection_id / endpoint
                     per-call overrides for the project vars.
-#}
{%- macro score(prompt, connection_id=none, endpoint=none, max_error_ratio=none) -%}
  {%- set mer = max_error_ratio if max_error_ratio is not none else var('bqai_max_error_ratio', none) -%}
AI.SCORE({{ prompt }}{{ bqai._bqai_managed_kwargs(connection_id, endpoint) }}
  {%- if mer is not none %}, max_error_ratio => {{ mer }}{% endif -%})
{%- endmacro -%}
