{#-
  Generic dbt tests provided by dbt-bqai.
-#}

{#-
  assert_embedding_dimension — asserts that an embedding column is not null
  and matches the expected vector length (e.g. 768 for text-embedding-004/005).
-#}
{% test assert_embedding_dimension(model, column_name, expected_dimension) %}

select *
from {{ model }}
where {{ column_name }} is null
   or array_length({{ column_name }}) != {{ expected_dimension }}

{% endtest %}


{#-
  assert_valid_category — asserts that a classification column contains only
  values present in the allowed_categories list.
-#}
{% test assert_valid_category(model, column_name, allowed_categories) %}

select *
from {{ model }}
where {{ column_name }} is not null
  and {{ column_name }} not in (
    {%- for cat in allowed_categories -%}
      '{{ cat | replace("'", "''") }}'{%- if not loop.last %}, {% endif -%}
    {%- endfor -%}
  )

{% endtest %}
