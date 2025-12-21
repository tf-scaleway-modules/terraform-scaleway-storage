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
# Individual Bucket Details (using expanded keys)
# ==============================================================================

output "data_buckets" {
  description = "Data buckets connection details (data-1, data-2, data-3)"
  value = {
    for k, v in module.storage.buckets : k => {
      name     = v.name
      endpoint = v.endpoint
    } if startswith(k, "data-")
  }
}

output "assets_bucket" {
  description = "Assets bucket connection details"
  value = {
    name     = module.storage.buckets["assets-1"].name
    endpoint = module.storage.bucket_endpoints["assets-1"]
    arn      = module.storage.bucket_arns["assets-1"]
  }
}

output "backup_bucket" {
  description = "Backup bucket connection details"
  value = {
    name     = module.storage.buckets["backup-1"].name
    endpoint = module.storage.bucket_endpoints["backup-1"]
    arn      = module.storage.bucket_arns["backup-1"]
  }
}

# ==============================================================================
# Website Information
# ==============================================================================

output "website_urls" {
  description = "Static website URLs (website-1 through website-4)"
  value       = module.storage.website_urls
}

output "website_details" {
  description = "Complete website configuration for first website bucket"
  value       = module.storage.website_endpoints["website-1"]
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
    ║  Website URLs: See website_urls output                           ║
    ║                                                                  ║
    ║  Buckets: See bucket_endpoints output for all ${length(module.storage.buckets)} buckets
    ║                                                                  ║
    ╚══════════════════════════════════════════════════════════════════╝

  EOT
}
