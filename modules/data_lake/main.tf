locals {
  bucket_name = "${var.name_prefix}-datalake-${var.environment}"

  # Glue/Athena identifiers with hyphens force quoting in every SQL query;
  # normalize to underscores so the database name is always query-friendly.
  glue_database_name = replace("${var.name_prefix}_${var.environment}", "-", "_")

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

# S3 accepts plain HTTP unless a policy says otherwise: encryption at rest
# (above) says nothing about the wire. This denies every request that did not
# arrive over TLS, for any principal and any action.
data "aws_iam_policy_document" "https_only" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.lake.arn,
      "${aws_s3_bucket.lake.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

# Server access logging, off by default: it needs a destination bucket, and
# creating one unasked would mean unrequested cost and a second bucket to
# manage. Point it at an existing log bucket to turn it on.
resource "aws_s3_bucket_logging" "lake" {
  count = var.access_log_bucket == "" ? 0 : 1

  bucket        = aws_s3_bucket.lake.id
  target_bucket = var.access_log_bucket
  target_prefix = var.access_log_prefix
}

resource "aws_s3_bucket_policy" "https_only" {
  bucket = aws_s3_bucket.lake.id
  policy = data.aws_iam_policy_document.https_only.json

  # The public access block sets `block_public_policy`, which rejects a policy
  # with a wildcard principal while it is being evaluated as "public". This
  # policy is a Deny, so it is not public, but the ordering still matters:
  # the block must exist first.
  depends_on = [aws_s3_bucket_public_access_block.lake]
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

  # Athena writes every query's results here and never cleans up after itself.
  # They are a cache (any query can be re-run), so they expire instead of
  # accumulating storage cost forever.
  rule {
    id     = "athena-results-expiration"
    status = "Enabled"

    filter {
      prefix = "athena-results/"
    }

    expiration {
      days = var.athena_results_expiration_days
    }
  }

  # Versioning is on (above), which is good for recovery but means every
  # overwrite keeps the old version forever. Left alone, noncurrent versions
  # are an invisible, unbounded storage bill. Expire them after a grace period
  # that still covers accidental overwrites.
  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }
}

# --- Glue data catalog ------------------------------------------------------

resource "aws_glue_catalog_database" "this" {
  name        = local.glue_database_name
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
