terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-west-1"
}

module "data_lake" {
  source = "../../modules/data_lake"

  name_prefix = "acme"
  environment = "dev"

  tags = {
    Team    = "data-platform"
    Project = "analytics"
  }
}

output "bucket_name" {
  value = module.data_lake.bucket_name
}

output "glue_database_name" {
  value = module.data_lake.glue_database_name
}

output "athena_workgroup" {
  value = module.data_lake.athena_workgroup
}
