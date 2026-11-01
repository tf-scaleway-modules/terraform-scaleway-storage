# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                         COMPLETE EXAMPLE OUTPUTS                              ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# Object Storage Outputs
# ==============================================================================

output "buckets" {
  description = "All buckets (id, name, region, endpoints, versioning, object lock, website endpoint, tags)"
  value       = module.storage.buckets
}

output "data_bucket" {
  description = "Data bucket details"
  value       = module.storage.buckets["data-1"]
}

output "website_endpoint" {
  description = "Static website endpoint reported by the provider"
  value       = module.storage.buckets["website-1"].website_endpoint
}

output "object_urls" {
  description = "URLs of uploaded objects"
  value       = { for k, v in module.storage.objects : k => v.url }
}

# ==============================================================================
# Block Storage Outputs
# ==============================================================================

output "block_volumes" {
  description = "All block storage volumes (uses expanded keys: database-1, app-1, app-2, logs-1)"
  value       = module.storage.block_volumes
}

output "database_volume_srn" {
  description = "Database volume Scaleway Resource Name"
  value       = module.storage.block_volumes["database-1"].srn
}

output "database_backup_srn" {
  description = "Database snapshot Scaleway Resource Name"
  value       = module.storage.block_snapshots["database_backup-1"].srn
}

output "database_volume_id" {
  description = "Database volume ID (for attaching to instances)"
  value       = module.storage.block_volumes["database-1"].id # Expanded key
}

output "app_volume_ids" {
  description = "Application volume IDs (count=2 creates app-1 and app-2)"
  value = {
    app_1 = module.storage.block_volumes["app-1"].id
    app_2 = module.storage.block_volumes["app-2"].id
  }
}

output "block_snapshots" {
  description = "All block storage snapshots (uses expanded keys); export holds the effective bucket and key"
  value       = module.storage.block_snapshots
}
