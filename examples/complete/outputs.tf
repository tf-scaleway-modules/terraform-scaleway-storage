# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                         COMPLETE EXAMPLE OUTPUTS                              ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# Object Storage Outputs
# ==============================================================================

output "s3_endpoint" {
  description = "S3 API endpoint for CLI/SDK configuration"
  value       = module.storage.s3_endpoint
}

output "bucket_names" {
  description = "All bucket names created"
  value       = module.storage.bucket_names
}

output "bucket_endpoints" {
  description = "S3 endpoints for each bucket"
  value       = module.storage.bucket_endpoints
}

output "data_bucket" {
  description = "Data bucket details"
  value       = module.storage.buckets["data-1"]
}

output "assets_bucket" {
  description = "Assets bucket details"
  value       = module.storage.buckets["assets-1"]
}

output "website_url" {
  description = "Static website URL"
  value       = module.storage.website_urls["website-1"]
}

output "object_urls" {
  description = "URLs of uploaded objects"
  value       = module.storage.object_urls
}

# ==============================================================================
# Block Storage Outputs
# ==============================================================================

output "block_volumes" {
  description = "All block storage volumes (uses expanded keys: database-1, app-1, app-2, logs-1)"
  value       = module.storage.block_volumes
}

output "block_volume_names" {
  description = "List of all block volume names"
  value       = module.storage.block_volume_names
}

output "database_volume_id" {
  description = "Database volume ID (for attaching to instances)"
  value       = module.storage.block_volume_ids["database-1"] # Expanded key
}

output "app_volume_ids" {
  description = "Application volume IDs (count=2 creates app-1 and app-2)"
  value = {
    app_1 = module.storage.block_volume_ids["app-1"]
    app_2 = module.storage.block_volume_ids["app-2"]
  }
}

output "block_snapshots" {
  description = "All block storage snapshots (uses expanded keys)"
  value       = module.storage.block_snapshots
}

output "block_snapshot_exports" {
  description = "Snapshots exported to Object Storage (QCOW2 files)"
  value       = module.storage.block_snapshot_exports
}

# ==============================================================================
# AWS CLI Configuration
# ==============================================================================

output "aws_cli_commands" {
  description = "Commands to configure AWS CLI for Scaleway"
  value       = module.storage.aws_cli_config.commands
}

output "environment_variables" {
  description = "Environment variables for S3-compatible tools"
  value       = module.storage.environment_variables
}
