###############################################################################
# OpenSearch Serverless Module — Variables
###############################################################################

# ── Collection ───────────────────────────────────────────────────────────────

variable "collection_name" {
  description = "Name of the OpenSearch Serverless collection"
  type        = string
  default     = "rag-vectors"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,31}$", var.collection_name))
    error_message = "Collection name must be 3-32 lowercase alphanumeric characters or hyphens, starting with a letter."
  }
}

# ── Vector Index ─────────────────────────────────────────────────────────────

variable "index_name" {
  description = "Name of the KNN vector index"
  type        = string
  default     = "rag-index"
}

variable "vector_dimension" {
  description = "Dimensionality of embedding vectors (Titan Embeddings V2 = 1024)"
  type        = number
  default     = 1024
}

variable "vector_engine" {
  description = "ANN engine for HNSW (faiss or nmslib)"
  type        = string
  default     = "faiss"

  validation {
    condition     = contains(["faiss", "nmslib"], var.vector_engine)
    error_message = "vector_engine must be 'faiss' or 'nmslib'."
  }
}

variable "space_type" {
  description = "Distance metric for similarity search"
  type        = string
  default     = "cosinesimil"

  validation {
    condition     = contains(["cosinesimil", "l2", "innerproduct"], var.space_type)
    error_message = "space_type must be one of: cosinesimil, l2, innerproduct."
  }
}

variable "hnsw_m" {
  description = "HNSW: number of bidirectional links per node (higher = better recall, more memory)"
  type        = number
  default     = 16
}

variable "hnsw_ef_construction" {
  description = "HNSW: size of dynamic candidate list during index build"
  type        = number
  default     = 512
}

variable "hnsw_ef_search" {
  description = "HNSW: size of dynamic candidate list during search"
  type        = number
  default     = 512
}

# ── Access Control ───────────────────────────────────────────────────────────

variable "data_access_principal_arns" {
  description = "IAM principal ARNs allowed data-plane access (deployer + ingestion roles)"
  type        = list(string)
}

# ── Deployment Control ───────────────────────────────────────────────────────

variable "create_index" {
  description = "Toggle for 2-pass deploy: false on 1st apply (collection only), true on 2nd apply (creates index)"
  type        = bool
  default     = false
}

# ── Tags ─────────────────────────────────────────────────────────────────────

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
