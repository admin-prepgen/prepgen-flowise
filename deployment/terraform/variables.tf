variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "db_tier" {
  description = "The machine type for the Cloud SQL instance"
  type        = string
  default     = "db-f1-micro"
  validation {
    condition = contains([
      "db-f1-micro",
      "db-g1-small",
      "db-custom-1-3840",
      "db-custom-2-7680",
      "db-custom-4-15360"
    ], var.db_tier)
    error_message = "The db_tier must be a valid Cloud SQL machine type."
  }
}

variable "redis_tier" {
  description = "The tier for the Redis instance"
  type        = string
  default     = "BASIC"
  validation {
    condition     = contains(["BASIC", "STANDARD_HA"], var.redis_tier)
    error_message = "The redis_tier must be either BASIC or STANDARD_HA."
  }
}

variable "redis_memory_size" {
  description = "The memory size in GiB for the Redis instance"
  type        = number
  default     = 1
  validation {
    condition     = var.redis_memory_size >= 1 && var.redis_memory_size <= 300
    error_message = "The redis_memory_size must be between 1 and 300 GiB."
  }
}

variable "environment" {
  description = "The deployment environment (dev, staging, prod)"
  type        = string
  default     = "prod"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "The environment must be one of: dev, staging, prod."
  }
}

variable "vpc_network" {
  description = "The name of the VPC network to use"
  type        = string
  default     = "default"
}