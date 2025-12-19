# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                         COMPLETE EXAMPLE OUTPUTS                              ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# Project Information
# ==============================================================================

output "project_id" {
  description = "Scaleway Project ID where resources are created"
  value       = module.storage.project_id
}

output "region" {
  description = "Deployment region"
  value       = module.storage.region
}

# ==============================================================================
# Bucket Information
# ==============================================================================

output "buckets" {
  description = "Complete details for all created buckets"
  value       = module.storage.buckets
}

output "bucket_endpoints" {
  description = "S3 endpoints for all buckets"
  value       = module.storage.bucket_endpoints
}

output "bucket_arns" {
  description = "ARN-style identifiers for bucket policies"
  value       = module.storage.bucket_arns
}

# ==============================================================================
# Individual Bucket Details
# ==============================================================================

output "data_bucket" {
  description = "Data bucket connection details"
  value = {
    name     = module.storage.buckets["data"].name
    endpoint = module.storage.bucket_endpoints["data"]
    arn      = module.storage.bucket_arns["data"]
  }
}

output "assets_bucket" {
  description = "Assets bucket connection details"
  value = {
    name     = module.storage.buckets["assets"].name
    endpoint = module.storage.bucket_endpoints["assets"]
    arn      = module.storage.bucket_arns["assets"]
  }
}

output "backup_bucket" {
  description = "Backup bucket connection details"
  value = {
    name     = module.storage.buckets["backup"].name
    endpoint = module.storage.bucket_endpoints["backup"]
    arn      = module.storage.bucket_arns["backup"]
  }
}

# ==============================================================================
# Website Information
# ==============================================================================

output "website_url" {
  description = "Static website URL"
  value       = module.storage.website_urls["website"]
}

output "website_details" {
  description = "Complete website configuration"
  value       = module.storage.website_endpoints["website"]
}

# ==============================================================================
# Object Information
# ==============================================================================

output "uploaded_objects" {
  description = "Details of all uploaded objects"
  value       = module.storage.objects
}

output "object_urls" {
  description = "Direct URLs to uploaded objects"
  value       = module.storage.object_urls
}

# ==============================================================================
# S3 Client Configuration
# ==============================================================================

output "s3_endpoint" {
  description = "S3 API endpoint for CLI/SDK configuration"
  value       = module.storage.s3_endpoint
}

output "aws_cli_commands" {
  description = "AWS CLI configuration commands"
  value       = module.storage.aws_cli_config.commands
}

output "environment_variables" {
  description = "Environment variables for S3 tools"
  value       = module.storage.environment_variables
}

# ==============================================================================
# Quick Reference
# ==============================================================================

output "quick_reference" {
  description = "Quick reference for common operations"
  value       = <<-EOT

    ╔══════════════════════════════════════════════════════════════════╗
    ║                    SCALEWAY STORAGE QUICK REFERENCE              ║
    ╠══════════════════════════════════════════════════════════════════╣
    ║                                                                  ║
    ║  S3 Endpoint: ${module.storage.s3_endpoint}
    ║                                                                  ║
    ║  AWS CLI Setup:                                                  ║
    ║  $ aws configure set s3.endpoint_url ${module.storage.s3_endpoint}
    ║  $ aws configure set default.region ${module.storage.region}
    ║                                                                  ║
    ║  Website URL:                                                    ║
    ║  ${module.storage.website_urls["website"]}
    ║                                                                  ║
    ║  Buckets:                                                        ║
    ║  - data:   ${module.storage.bucket_endpoints["data"]}
    ║  - assets: ${module.storage.bucket_endpoints["assets"]}
    ║  - backup: ${module.storage.bucket_endpoints["backup"]}
    ║                                                                  ║
    ╚══════════════════════════════════════════════════════════════════╝

  EOT
}
