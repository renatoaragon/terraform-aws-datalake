locals {
  bucket_name = "${var.name_prefix}-datalake-${var.environment}"

  tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "terraform"
      Module      = "data_lake"
    },
    var.tags,
  )
}

# --- Data lake bucket -------------------------------------------------------

resource "aws_s3_bucket" "lake" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy
  tags          = local.tags
}

resource "aws_s3_bucket_versioning" "lake" {
  bucket = aws_s3_bucket.lake.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lake" {
  bucket = aws_s3_bucket.lake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "lake" {
  bucket = aws_s3_bucket.lake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "lake" {
  bucket = aws_s3_bucket.lake.id

  rule {
    id     = "raw-transition-to-ia"
    status = "Enabled"

    filter {
      prefix = "raw/"
    }

    transition {
      days          = var.raw_transition_days
      storage_class = "STANDARD_IA"
    }
  }
}

# --- Glue data catalog ------------------------------------------------------

resource "aws_glue_catalog_database" "this" {
  name        = "${var.name_prefix}_${var.environment}"
  description = "Catalog database for the ${var.name_prefix} data lake (${var.environment})."
}

# --- Athena workgroup -------------------------------------------------------

resource "aws_athena_workgroup" "this" {
  name  = "${var.name_prefix}-${var.environment}"
  tags  = local.tags
  state = "ENABLED"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.lake.bucket}/athena-results/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }
}
