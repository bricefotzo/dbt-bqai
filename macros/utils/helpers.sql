{#-
  Internal helpers for dbt-bqai. Not part of the public API — names are
  prefixed with `_bqai_` and may change between releases.

  Config resolution order for every setting is:
    1. the value passed to the macro call (per-call override), else
    2. the corresponding `bqai_*` project var, else
    3. nothing is emitted (BigQuery applies its own default).
-#}


{#-
  Emit the trailing named arguments shared by the general-purpose AI.GENERATE*
  functions: connection_id, endpoint, model_params, request_type.

  Each piece is prefixed with ", " so the caller can append it directly after
  the prompt argument. `model_params` is rendered as a JSON-typed literal
  (`JSON '...'`), which is what these functions require.
-#}
{%- macro _bqai_gen_kwargs(connection_id, endpoint, model_params, request_type) -%}
  {%- set conn = connection_id if connection_id is not none else var('bqai_connection', none) -%}
  {%- set ep = endpoint if endpoint is not none else var('bqai_endpoint', none) -%}
  {%- set mp = model_params if model_params is not none else var('bqai_model_params', none) -%}
  {%- if conn is not none %}, connection_id => '{{ conn }}'{% endif -%}
  {%- if ep is not none %}, endpoint => '{{ ep }}'{% endif -%}
  {%- if mp is not none %}, model_params => JSON '''{{ mp }}'''{% endif -%}
  {%- if request_type is not none %}, request_type => '{{ request_type }}'{% endif -%}
{%- endmacro -%}


{#-
  Emit the connection_id and endpoint named arguments shared by the managed
  functions (AI.CLASSIFY / AI.SCORE / AI.IF). These functions also accept an
  endpoint, so we default it from `bqai_endpoint` just like the generate
  functions. `max_error_ratio` and the optimization arguments are handled by
  each managed macro individually because their interactions differ.
-#}
{%- macro _bqai_managed_kwargs(connection_id, endpoint) -%}
  {%- set conn = connection_id if connection_id is not none else var('bqai_connection', none) -%}
  {%- set ep = endpoint if endpoint is not none else var('bqai_endpoint', none) -%}
  {%- if conn is not none %}, connection_id => '{{ conn }}'{% endif -%}
  {%- if ep is not none %}, endpoint => '{{ ep }}'{% endif -%}
{%- endmacro -%}


{#-
  Render a categories/array argument.

  - A string is assumed to be a raw SQL expression and is passed through
    untouched (e.g. a column, an ARRAY subquery, or a hand-written array
    literal such as "['a', 'b']").
  - A list/tuple is rendered as a BigQuery array literal. String items are
    quoted (single quotes doubled for safety); non-string items (e.g. nested
    tuples for labeled categories) are emitted as-is.
-#}
{%- macro _bqai_array(value) -%}
  {%- if value is string -%}
    {{ value }}
  {%- else -%}
    [
    {%- for item in value -%}
      {%- if not loop.first %}, {% endif -%}
      {%- if item is string -%}'{{ item | replace("'", "''") }}'{%- else -%}{{ item }}{%- endif -%}
    {%- endfor -%}
    ]
  {%- endif -%}
{%- endmacro -%}
