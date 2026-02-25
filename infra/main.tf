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
    # Add ingestion role ARN when available (Week 3):
    # aws_iam_role.ingestion.arn,
  ]

  tags = var.default_tags
}
