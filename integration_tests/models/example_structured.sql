-- Structured output via output_schema: the macro returns the full STRUCT and
-- we splat the schema fields, dropping the bookkeeping columns.
with complaints as (
    select 1 as complaint_id, 'Charged twice for one order, very upset.' as narrative
)

select
    complaint_id,
    {{ bqai.generate(
        "CONCAT('Analyze this complaint: ', narrative)",
        output_schema="complaint_type STRING, severity INT64"
    ) }}.* except (full_response, status)
from complaints
