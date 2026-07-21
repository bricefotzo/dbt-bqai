-- Exercises the scalar generate/classify/score/ai_if macros in one model.
-- Uses an inline CTE so it compiles and runs without any upstream tables.
with reviews as (
    select 1 as review_id, 'The battery life is amazing and it was cheap.' as review
    union all
    select 2 as review_id, 'Terrible support, would not buy again.' as review
)

select
    review_id,
    review,
    {{ bqai.classify("review", ["positive", "neutral", "negative"]) }} as sentiment,
    {{ bqai.score("('Rate how positive this review is, 1-10: ', review)") }} as positivity,
    {{ bqai.generate("CONCAT('Summarize in one line: ', review)") }} as summary,
    {{ bqai.generate_bool("('Is this review a complaint? ', review)") }} as is_complaint
from reviews
where {{ bqai.ai_if("('This review mentions the product price: ', review)") }}
