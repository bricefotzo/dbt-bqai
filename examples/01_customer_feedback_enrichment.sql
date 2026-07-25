/*
  ===============================================================================
  Example 01: Customer Feedback Enrichment
  ===============================================================================
  Demonstrates using scalar BigQuery AI macros to enrich unstructured customer
  reviews in a single dbt model:
    - bqai.classify: Categorizes feedback into positive / neutral / negative.
    - bqai.score: Produces a 1-10 numerical score for positivity.
    - bqai.generate: Generates a concise one-line executive summary.
    - bqai.ai_if: Filters rows in the WHERE clause based on natural language logic.
  ===============================================================================
*/

with raw_reviews as (
    select
        1 as review_id,
        '2026-07-20' as review_date,
        'The battery life is amazing and charging is super fast, but customer support was slow.' as review_text
    union all
    select
        2 as review_id,
        '2026-07-21' as review_date,
        'Terrible product. Broke after two days and the price was way too high for this quality.' as review_text
    union all
    select
        3 as review_id,
        '2026-07-22' as review_date,
        'Decent quality, arrived on time. Everything works as expected.' as review_text
)

select
    review_id,
    review_date,
    review_text,

    -- 1. Classify sentiment into fixed categories
    {{ bqai.classify("review_text", ["positive", "neutral", "negative"]) }} as sentiment,

    -- 2. Score positivity on a 1-10 scale
    {{ bqai.score("('Rate positivity 1-10: ', review_text)") }} as positivity_score,

    -- 3. Summarize key points in one sentence
    {{ bqai.generate("CONCAT('Summarize this review in one sentence: ', review_text)") }} as executive_summary,

    -- 4. Check if the review is classified as a complaint
    {{ bqai.generate_bool("('Is this review a complaint? ', review_text)") }} as is_complaint

from raw_reviews

-- 5. Filter dynamically for reviews mentioning product price or cost
where {{ bqai.ai_if("('This review mentions product price or cost: ', review_text)") }}
