# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                         MINIMAL EXAMPLE OUTPUTS                               ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

output "bucket_name" {
  description = "Name of the created bucket"
  value       = module.storage.bucket_names[0]
}

output "bucket_endpoint" {
  description = "S3 endpoint for the bucket"
  value       = module.storage.bucket_endpoints["data"]
}

output "s3_endpoint" {
  description = "S3 API endpoint for CLI/SDK configuration"
  value       = module.storage.s3_endpoint
}

output "bucket_arn" {
  description = "ARN-style identifier for use in policies"
  value       = module.storage.bucket_arns["data"]
}
