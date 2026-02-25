###############################################################################
# Root — Variables
###############################################################################

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "default_tags" {
  description = "Default tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "bedrock-rag"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

variable "create_index" {
  description = "Toggle for 2-pass deploy: false on 1st apply, true on 2nd apply"
  type        = bool
  default     = false
}
