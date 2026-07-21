{#-
  General-purpose generative macros wrapping the AI.GENERATE* function family.
  You control the prompt and (optionally) the model.

  `prompt` is a RAW SQL expression — a column, a CONCAT(...), or a
  (string, column) tuple — NOT a quoted string literal. Everything the macro
  emits is a scalar SQL expression you can drop into a SELECT / WHERE.
-#}


{#-
  AI.GENERATE — returns STRING by default, or a structured value when
  `output_schema` is given.

  Args:
    prompt         raw SQL expression for the prompt (required)
    output_schema  column definitions for structured output, WITHOUT the outer
                   quotes, e.g. "name STRING, age INT64". When set, the model
                   returns a STRUCT whose fields are those columns (plus
                   full_response and status) and `.result` does not exist, so
                   the macro returns the full STRUCT regardless of `extract`.
    extract        when true (default) and no output_schema, return `.result`;
                   when false, return the full STRUCT<result, full_response,
                   status>.
    connection_id / endpoint / model_params / request_type
                   per-call overrides for the project vars.
-#}
{%- macro generate(prompt, output_schema=none, extract=true, connection_id=none, endpoint=none, model_params=none, request_type=none) -%}
  {%- set schema_part = (", output_schema => '" ~ output_schema ~ "'") if output_schema is not none else "" -%}
  {%- set inner = "AI.GENERATE(" ~ prompt ~ bqai._bqai_gen_kwargs(connection_id, endpoint, model_params, request_type) ~ schema_part ~ ")" -%}
  {%- if output_schema is not none or not extract -%}
({{ inner }})
  {%- else -%}
({{ inner }}).result
  {%- endif -%}
{%- endmacro -%}


{#- AI.GENERATE_BOOL — returns BOOL (via `.result`). -#}
{%- macro generate_bool(prompt, extract=true, connection_id=none, endpoint=none, model_params=none, request_type=none) -%}
  {%- set inner = "AI.GENERATE_BOOL(" ~ prompt ~ bqai._bqai_gen_kwargs(connection_id, endpoint, model_params, request_type) ~ ")" -%}
  {%- if extract -%}({{ inner }}).result{%- else -%}({{ inner }}){%- endif -%}
{%- endmacro -%}


{#- AI.GENERATE_INT — returns INT64 (via `.result`). -#}
{%- macro generate_int(prompt, extract=true, connection_id=none, endpoint=none, model_params=none, request_type=none) -%}
  {%- set inner = "AI.GENERATE_INT(" ~ prompt ~ bqai._bqai_gen_kwargs(connection_id, endpoint, model_params, request_type) ~ ")" -%}
  {%- if extract -%}({{ inner }}).result{%- else -%}({{ inner }}){%- endif -%}
{%- endmacro -%}


{#- AI.GENERATE_DOUBLE — returns FLOAT64 (via `.result`). -#}
{%- macro generate_double(prompt, extract=true, connection_id=none, endpoint=none, model_params=none, request_type=none) -%}
  {%- set inner = "AI.GENERATE_DOUBLE(" ~ prompt ~ bqai._bqai_gen_kwargs(connection_id, endpoint, model_params, request_type) ~ ")" -%}
  {%- if extract -%}({{ inner }}).result{%- else -%}({{ inner }}){%- endif -%}
{%- endmacro -%}
