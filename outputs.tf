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
  description = "Map of all created buckets keyed by expanded bucket key (for example `data-1`). Each entry holds `id`, `name`, `region`, `endpoint`, `api_endpoint`, `versioning_enabled`, `object_lock_enabled`, `website_endpoint` (`null` without a website) and `tags`."
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
  description = "Map of all uploaded objects keyed like the `objects` input. Each entry holds `id`, `bucket`, `key`, `url` (bucket endpoint plus key), `content_type` and `visibility`."
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
  description = "Map of all created Block Storage volumes keyed by expanded key (for example `database-1`). Each entry holds `id` (zoned `zone/uuid`), `srn`, `name`, `size_in_gb`, `iops`, `zone`, `volume_key` (key before expansion) and `index`."
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
  description = "Map of all created Block Storage snapshots, volume-based and imported, keyed by expanded key (for example `backup-1`). Each entry holds `id`, `srn`, `name`, `volume_id` (`null` for imported snapshots), `zone`, `snapshot_key` (key before expansion), `index`, `source` (`volume` or `import`) and `export` (bucket and key, if configured)."
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
