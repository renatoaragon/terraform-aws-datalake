variable "name_prefix" {
  description = "Prefix used to name the bucket and catalog resources."
  type        = string
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
