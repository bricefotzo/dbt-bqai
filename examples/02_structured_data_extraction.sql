/*
  ===============================================================================
  Example 02: Structured Data Extraction (JSON to Typed Structs)
  ===============================================================================
  Demonstrates using bqai.generate with `output_schema` to parse raw,
  unstructured support emails into strongly-typed BigQuery STRUCT columns
  (e.g., ticket_type, urgency_level, customer_intent).

  Key Benefit:
    When `output_schema` is supplied, BigQuery AI returns a STRUCT<...>.
    Using `.* except (full_response, status)` automatically expands the fields
    into individual typed SQL columns in your model.
  ===============================================================================
*/

with raw_support_emails as (
    select
        101 as email_id,
        'URGENT: Billing error on invoice #9402. I was double-charged $49.99 on my Visa card yesterday.' as email_body
    union all
    select
        102 as email_id,
        'Hi, I would like to request a demo of your enterprise plan for a team of 50 engineers.' as email_body
)

select
    email_id,
    email_body,

    -- Extract structured attributes directly into typed BigQuery columns
    {{ bqai.generate(
        "CONCAT('Analyze support ticket details: ', email_body)",
        output_schema="category STRING, urgency INT64, requested_action STRING, estimated_amount FLOAT64"
    ) }}.* except (full_response, status)

from raw_support_emails
