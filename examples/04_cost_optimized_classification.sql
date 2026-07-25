/*
  ===============================================================================
  Example 04: Cost-Optimized Classification
  ===============================================================================
  Demonstrates high-throughput, cost-optimized classification on large tables
  using optimized embeddings mode (`embeddings=...`) and cost control settings
  (`max_error_ratio=...`, `optimization_mode='MINIMIZE_COST'`).
  ===============================================================================
*/

with precomputed_embeddings as (
    select
        article_id,
        body_text,

        -- Step 1: Compute embedding vector once
        {{ bqai.embed("body_text", task_type="SEMANTIC_SIMILARITY") }} as doc_embedding
    from {{ ref('stg_articles') }}
)

select
    article_id,
    body_text,

    -- Step 2: Pass precomputed embeddings to bqai.classify for accelerated, low-cost routing
    {{ bqai.classify(
        "body_text",
        ["technology", "finance", "sports", "entertainment"],
        embeddings="doc_embedding",
        optimization_mode="MINIMIZE_COST"
    ) }} as topic_category

from precomputed_embeddings
