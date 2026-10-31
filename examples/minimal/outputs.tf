# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                         MINIMAL EXAMPLE OUTPUTS                               ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

output "bucket_name" {
  description = "Name of the created bucket"
  value       = module.storage.buckets["data-1"].name # Expanded key (count=1)
}

output "bucket_endpoint" {
  description = "S3 endpoint for the bucket, as reported by the provider"
  value       = module.storage.buckets["data-1"].endpoint
}

output "s3_endpoint" {
  description = "Region-level S3 API endpoint for CLI/SDK configuration"
  value       = module.storage.buckets["data-1"].api_endpoint
}
