# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              MODULE OUTPUTS                                   ║
# ║                                                                                ║
# ║  Outputs for integrating with other modules and external systems.             ║
# ║  No output carries a secret.                                                  ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# Bucket Outputs
# ------------------------------------------------------------------------------
# Complete information about all created buckets. Endpoints are reported by
# the provider, so they follow whatever region the buckets are in.
# ==============================================================================

output "buckets" {
  description = <<-EOT
    Map of all created buckets with their complete details, keyed by expanded
    bucket key (e.g., "data-1").

    Each bucket includes:
    - id: Scaleway resource ID
    - name: Bucket name
    - region: Region of the bucket
    - endpoint: S3 bucket endpoint URL (reported by the provider)
    - api_endpoint: S3 API endpoint (reported by the provider)
    - versioning_enabled: Whether versioning is active
    - object_lock_enabled: Whether WORM is enabled
    - website_endpoint: Static website endpoint (null without a website)
    - tags: Applied tags
  EOT
  value = {
    for k, v in scaleway_object_bucket.this : k => {
      id                  = v.id
      name                = v.name
      region              = v.region
      endpoint            = v.endpoint
      api_endpoint        = v.api_endpoint
      versioning_enabled  = v.versioning[0].enabled
      object_lock_enabled = v.object_lock_enabled
      website_endpoint    = local.expanded_buckets[k].website != null ? scaleway_object_bucket_website_configuration.this[k].website_endpoint : null
      tags                = v.tags
    }
  }
}

# ==============================================================================
# Objects Outputs
# ------------------------------------------------------------------------------
# Information about uploaded objects.
# ==============================================================================

output "objects" {
  description = <<-EOT
    Map of all uploaded objects with their details, keyed like the objects input.

    Each object includes:
    - id: Scaleway resource ID
    - bucket: Bucket name
    - key: Object key
    - url: Object URL (the bucket endpoint reported by the provider, then the key)
    - content_type: MIME type
    - visibility: private or public-read
  EOT
  value = {
    for k, v in scaleway_object.this : k => {
      id           = v.id
      bucket       = v.bucket
      key          = v.key
      url          = "${scaleway_object_bucket.this[var.objects[k].bucket_key].endpoint}/${v.key}"
      content_type = v.content_type
      visibility   = v.visibility
    }
  }
}

# ==============================================================================
# Block Storage Outputs
# ------------------------------------------------------------------------------
# Information about Block Storage volumes and snapshots.
# Keys use expanded format (e.g., "database-1", "database-2").
# ==============================================================================

output "block_volumes" {
  description = <<-EOT
    Map of all created Block Storage volumes with their details.

    Keys use expanded format (e.g., "database-1", "database-2").

    Each volume includes:
    - id: Volume ID (zoned format: zone/uuid)
    - srn: Scaleway Resource Name
    - name: Volume name
    - size_in_gb: Volume size
    - iops: IOPS performance tier
    - zone: Availability Zone
    - volume_key: Original volume key (before expansion)
    - index: Instance index (1, 2, 3, ...)
  EOT
  value = {
    for k, v in scaleway_block_volume.this : k => {
      id         = v.id
      srn        = v.srn
      name       = v.name
      size_in_gb = v.size_in_gb
      iops       = v.iops
      zone       = v.zone
      volume_key = local.expanded_block_volumes[k].volume_key
      index      = local.expanded_block_volumes[k].index
    }
  }
}

output "block_snapshots" {
  description = <<-EOT
    Map of all created Block Storage snapshots with their details.

    Keys use expanded format (e.g., "backup-1", "backup-2").
    Includes both volume-based and imported snapshots.

    Each snapshot includes:
    - id: Snapshot ID
    - srn: Scaleway Resource Name
    - name: Snapshot name
    - volume_id: Source volume ID (null for imported snapshots)
    - zone: Availability Zone
    - snapshot_key: Original snapshot key (before expansion)
    - index: Instance index (1, 2, 3, ...)
    - source: "volume" or "import"
    - export: Export details if configured (bucket, key)
  EOT
  value = merge(
    # Snapshots from volumes
    {
      for k, v in scaleway_block_snapshot.this : k => {
        id           = v.id
        srn          = v.srn
        name         = v.name
        volume_id    = v.volume_id
        zone         = v.zone
        snapshot_key = local.expanded_block_snapshots[k].snapshot_key
        index        = local.expanded_block_snapshots[k].index
        source       = "volume"
        export       = local.expanded_block_snapshots[k].export
      }
    },
    # Imported snapshots
    {
      for k, v in scaleway_block_snapshot.imported : k => {
        id           = v.id
        srn          = v.srn
        name         = v.name
        volume_id    = null
        zone         = v.zone
        snapshot_key = local.expanded_block_snapshots[k].snapshot_key
        index        = local.expanded_block_snapshots[k].index
        source       = "import"
        export       = local.expanded_block_snapshots[k].export
      }
    }
  )
}
