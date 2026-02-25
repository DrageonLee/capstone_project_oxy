###############################################################################
# Embedding Module — Variables
###############################################################################

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "corpus_bucket" {
  description = "S3 bucket containing corpus.json"
  type        = string
}

variable "corpus_key" {
  description = "S3 key for corpus.json"
  type        = string
  default     = "processed/corpus.json"
}

variable "output_bucket" {
  description = "S3 bucket for embedding output"
  type        = string
}

variable "output_prefix" {
  description = "S3 prefix for embedding files"
  type        = string
  default     = "embeddings/"
}

variable "model_id" {
  description = "Bedrock embedding model ID"
  type        = string
  default     = "amazon.titan-embed-text-v2:0"
}

variable "batch_size" {
  description = "Documents per Lambda invocation"
  type        = number
  default     = 25
}

variable "max_retries" {
  description = "Max Bedrock API retries"
  type        = number
  default     = 3
}

variable "tags" {
  type    = map(string)
  default = {}
}
