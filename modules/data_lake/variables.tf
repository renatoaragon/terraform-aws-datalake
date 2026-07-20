variable "name_prefix" {
  description = "Prefix used to name the bucket and catalog resources."
  type        = string

  # The prefix ends up in an S3 bucket name, so it must obey bucket rules at
  # plan time: lowercase alphanumerics and hyphens, no leading/trailing hyphen.
  # 2-40 chars keeps "<prefix>-datalake-<environment>" under the 63-char limit.
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,38}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix must be 2-40 chars of lowercase letters, digits and hyphens, starting and ending alphanumeric (it becomes part of an S3 bucket name)."
  }
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "raw_transition_days" {
  description = "Days before raw objects transition to STANDARD_IA storage."
  type        = number
  default     = 30

  # STANDARD_IA rejects transitions below 30 days; catching it at plan time
  # beats a mid-apply failure from the S3 API.
  validation {
    condition     = var.raw_transition_days >= 30
    error_message = "raw_transition_days must be >= 30: S3 rejects STANDARD_IA transitions below 30 days."
  }
}

variable "athena_results_expiration_days" {
  description = "Days before Athena query results are deleted. Results are a cache, not data."
  type        = number
  default     = 30

  validation {
    condition     = var.athena_results_expiration_days >= 1
    error_message = "athena_results_expiration_days must be at least 1."
  }
}

variable "access_log_bucket" {
  description = "Existing bucket to receive S3 server access logs. Empty disables logging."
  type        = string
  default     = ""
}

variable "access_log_prefix" {
  description = "Key prefix for the access logs in access_log_bucket."
  type        = string
  default     = "s3-access-logs/"
}

variable "force_destroy" {
  description = "Allow deleting the bucket even when it still contains objects."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
