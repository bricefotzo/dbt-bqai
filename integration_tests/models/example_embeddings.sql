-- Embeddings via AI.EMBED.
with docs as (
    select 'doc-1' as doc_id, 'BigQuery AI functions call Gemini directly from SQL.' as body
)

select
    doc_id,
    {{ bqai.embed("body", task_type="SEMANTIC_SIMILARITY") }} as embedding
from docs
