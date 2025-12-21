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
  # S3 Endpoints
  # ---------------------------------------------------------------------------
  # Scaleway Object Storage uses S3-compatible endpoints.
  # Format: https://s3.<region>.scw.cloud
  # ===========================================================================

  s3_endpoint = "https://s3.${var.region}.scw.cloud"

}
