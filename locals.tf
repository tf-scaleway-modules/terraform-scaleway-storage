# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              LOCAL VALUES                                     ║
# ║                                                                                ║
# ║  Computed values and transformations used throughout the module.              ║
# ║  These simplify resource configurations and output formatting.                ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

locals {
  # ===========================================================================
  # Bucket Expansion
  # ---------------------------------------------------------------------------
  # Expands bucket configurations based on count parameter.
  # Example: A bucket with count=3 becomes bucket-1, bucket-2, bucket-3
  # ===========================================================================

  expanded_buckets = merge([
    for key, bucket in var.buckets : {
      for i in range(1, bucket.count + 1) : "${key}-${i}" => merge(bucket, {
        name       = bucket.count > 1 ? "${bucket.name}-${i}" : bucket.name
        bucket_key = key
        index      = i
      })
    }
  ]...)

  # ===========================================================================
  # Block Volume Expansion
  # ---------------------------------------------------------------------------
  # Expands block volume configurations based on count parameter.
  # Example: A volume with count=3 becomes volume-1, volume-2, volume-3
  # ===========================================================================

  expanded_block_volumes = merge([
    for key, volume in var.block_volumes : {
      for i in range(1, volume.count + 1) : "${key}-${i}" => merge(volume, {
        name            = volume.name != null ? (volume.count > 1 ? "${volume.name}-${i}" : volume.name) : (volume.count > 1 ? "${key}-${i}-volume" : "${key}-volume")
        volume_key      = key
        index           = i
        prevent_destroy = volume.prevent_destroy
      })
    }
  ]...)

  # ===========================================================================
  # Block Snapshot Expansion
  # ---------------------------------------------------------------------------
  # Expands block snapshot configurations based on count parameter.
  # Example: A snapshot with count=3 becomes snapshot-1, snapshot-2, snapshot-3
  # Supports export to Object Storage and import from Object Storage.
  # ===========================================================================

  expanded_block_snapshots = merge([
    for key, snapshot in var.block_snapshots : {
      for i in range(1, snapshot.count + 1) : "${key}-${i}" => merge(snapshot, {
        name         = snapshot.name != null ? (snapshot.count > 1 ? "${snapshot.name}-${i}" : snapshot.name) : (snapshot.count > 1 ? "${key}-${i}-snapshot" : "${key}-snapshot")
        snapshot_key = key
        index        = i
        # For export, append index to key if count > 1 to avoid overwrites
        export = snapshot.export != null ? {
          bucket = snapshot.export.bucket
          key    = snapshot.count > 1 ? replace(snapshot.export.key, "/(\\.qcow2?)$/", "-${i}$1") : snapshot.export.key
        } : null
        # Import stays the same (typically count=1 for imports)
        import = snapshot.import
      })
    }
  ]...)

  # ===========================================================================
  # S3 Endpoints
  # ---------------------------------------------------------------------------
  # Scaleway Object Storage uses S3-compatible endpoints.
  # Format: https://s3.<region>.scw.cloud
  # ===========================================================================

  s3_endpoint = "https://s3.${var.region}.scw.cloud"

}
