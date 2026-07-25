/*
  ===============================================================================
  Example 03: Semantic Embeddings for Vector Search
  ===============================================================================
  Demonstrates generating text embeddings using `bqai.embed` with Gemini embedding
  models (e.g., text-embedding-005). The output ARRAY<FLOAT64> column can be stored
  in BigQuery tables for vector similarity search using `VECTOR_SEARCH`.
  ===============================================================================
*/

with knowledge_base_docs as (
    select
        'doc_001' as doc_id,
        'Getting Started' as title,
        'To configure BigQuery AI connections, assign Vertex AI User role to the Cloud resource connection service account.' as content
    union all
    select
        'doc_002' as doc_id,
        'Cost Management' as title,
        'Set thinking_budget to 0 in bqai_model_params for latency and cost sensitive batch transformations.' as content
)

select
    doc_id,
    title,
    content,

    -- Generate a semantic vector embedding (ARRAY<FLOAT64>)
    {{ bqai.embed(
        "content",
        task_type="RETRIEVAL_DOCUMENT",
        title="title"
    ) }} as embedding_vector

from knowledge_base_docs
