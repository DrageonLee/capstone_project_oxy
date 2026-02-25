###############################################################################
# OpenSearch Serverless Module — Main
#
# Creates:
#   1. Encryption policy  (AWS owned key)
#   2. Network policy      (public, dev-only — switch to VPC later)
#   3. VECTORSEARCH collection
#   4. Data access policy  (collection + index level permissions)
#   5. Vector index        (null_resource + local-exec Python, gated by create_index)
###############################################################################

locals {
  collection = var.collection_name
}

# ── 1. Encryption Policy ────────────────────────────────────────────────────

resource "aws_opensearchserverless_security_policy" "encryption" {
  name = "${local.collection}-enc"
  type = "encryption"

  policy = jsonencode({
    Rules = [
      {
        ResourceType = "collection"
        Resource     = ["collection/${local.collection}"]
      }
    ]
    AWSOwnedKey = true
  })
}

# ── 2. Network Policy ──────────────────────────────────────────────────────

resource "aws_opensearchserverless_security_policy" "network" {
  name = "${local.collection}-net"
  type = "network"

  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${local.collection}"]
        },
        {
          ResourceType = "dashboard"
          Resource     = ["collection/${local.collection}"]
        }
      ]
      AllowFromPublic = true
    }
  ])
}

# ── 3. Collection ──────────────────────────────────────────────────────────

resource "aws_opensearchserverless_collection" "this" {
  name = local.collection
  type = "VECTORSEARCH"
  tags = var.tags

  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network,
  ]
}

# ── 4. Data Access Policy ──────────────────────────────────────────────────
#
# Includes BOTH collection-level and index-level permissions to avoid 403s.

resource "aws_opensearchserverless_access_policy" "this" {
  name = "${local.collection}-access"
  type = "data"

  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${local.collection}"]
          Permission = [
            "aoss:DescribeCollectionItems"
          ]
        },
        {
          ResourceType = "index"
          Resource     = ["index/${local.collection}/*"]
          Permission = [
            "aoss:CreateIndex",
            "aoss:DeleteIndex",
            "aoss:UpdateIndex",
            "aoss:DescribeIndex",
            "aoss:ReadDocument",
            "aoss:WriteDocument"
          ]
        }
      ]
      Principal = var.data_access_principal_arns
    }
  ])
}

# ── 5. Vector Index (null_resource + local-exec) ───────────────────────────
#
# Gated by var.create_index (default false).
# Uses Python script with opensearch-py + SigV4 auth.

resource "null_resource" "vector_index" {
  count = var.create_index ? 1 : 0

  triggers = {
    index_name       = var.index_name
    vector_dimension = var.vector_dimension
    vector_engine    = var.vector_engine
    space_type       = var.space_type
    hnsw_m           = var.hnsw_m
    ef_construction  = var.hnsw_ef_construction
    ef_search        = var.hnsw_ef_search
    endpoint         = aws_opensearchserverless_collection.this.collection_endpoint
  }

  provisioner "local-exec" {
    command = <<-EOT
      python3 ${path.module}/scripts/create_index.py \
        --endpoint "${aws_opensearchserverless_collection.this.collection_endpoint}" \
        --index-name "${var.index_name}" \
        --dimension ${var.vector_dimension} \
        --engine "${var.vector_engine}" \
        --space-type "${var.space_type}" \
        --hnsw-m ${var.hnsw_m} \
        --ef-construction ${var.hnsw_ef_construction} \
        --ef-search ${var.hnsw_ef_search}
    EOT
  }

  depends_on = [
    aws_opensearchserverless_collection.this,
    aws_opensearchserverless_access_policy.this,
  ]
}
