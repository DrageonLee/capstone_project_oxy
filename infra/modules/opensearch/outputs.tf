###############################################################################
# OpenSearch Serverless Module — Outputs
###############################################################################

output "collection_endpoint" {
  description = "OpenSearch Serverless collection endpoint URL"
  value       = aws_opensearchserverless_collection.this.collection_endpoint
}

output "collection_arn" {
  description = "ARN of the OpenSearch Serverless collection"
  value       = aws_opensearchserverless_collection.this.arn
}

output "collection_id" {
  description = "ID of the OpenSearch Serverless collection"
  value       = aws_opensearchserverless_collection.this.id
}

output "dashboard_endpoint" {
  description = "OpenSearch Dashboards endpoint URL"
  value       = aws_opensearchserverless_collection.this.dashboard_endpoint
}

output "index_name" {
  description = "Name of the vector index"
  value       = var.index_name
}
