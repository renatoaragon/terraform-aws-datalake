output "bucket_name" {
  description = "Name of the data lake S3 bucket."
  value       = aws_s3_bucket.lake.bucket
}

output "bucket_arn" {
  description = "ARN of the data lake S3 bucket."
  value       = aws_s3_bucket.lake.arn
}

output "glue_database_name" {
  description = "Name of the Glue catalog database."
  value       = aws_glue_catalog_database.this.name
}

output "athena_workgroup" {
  description = "Name of the Athena workgroup."
  value       = aws_athena_workgroup.this.name
}
