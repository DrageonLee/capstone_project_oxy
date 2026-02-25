###############################################################################
# Root — Main
###############################################################################

data "aws_caller_identity" "current" {}

# ── OpenSearch Serverless ──────────────────────────────────────────────────

module "opensearch" {
  source = "./modules/opensearch"

  collection_name  = "rag-vectors"
  index_name       = "rag-index"
  vector_dimension = 1024 # Bedrock Titan Embeddings V2
  create_index     = var.create_index

  data_access_principal_arns = [
    data.aws_caller_identity.current.arn,
    module.embedding.lambda_role_arn,
  ]

  tags = var.default_tags
}

# ── Embedding Pipeline ─────────────────────────────────────────────────────

module "embedding" {
  source = "./modules/embedding"

  aws_region    = var.aws_region
  corpus_bucket = var.corpus_bucket
  output_bucket = var.corpus_bucket  # 같은 버킷에 저장 (원하면 별도 버킷으로 분리 가능)
  tags          = var.default_tags
}
