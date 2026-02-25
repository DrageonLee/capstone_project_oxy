###############################################################################
# Root — Outputs
###############################################################################

output "opensearch_collection_endpoint" {
  description = "OpenSearch Serverless collection endpoint"
  value       = module.opensearch.collection_endpoint
}

output "opensearch_collection_arn" {
  description = "OpenSearch Serverless collection ARN"
  value       = module.opensearch.collection_arn
}

output "opensearch_dashboard_endpoint" {
  description = "OpenSearch Dashboards endpoint"
  value       = module.opensearch.dashboard_endpoint
}

output "opensearch_index_name" {
  description = "Vector index name"
  value       = module.opensearch.index_name
}
