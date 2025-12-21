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

  # ===========================================================================
  # Bucket Endpoint Maps
  # ---------------------------------------------------------------------------
  # Pre-computed endpoint URLs for each bucket.
  # Useful for constructing URLs and integration configurations.
  # ===========================================================================

  bucket_endpoints = {
    for k, v in scaleway_object_bucket.this : k => {
      # Standard S3 endpoint for API access
      endpoint = "https://${v.name}.s3.${var.region}.scw.cloud"

      # Website endpoint (only valid if website hosting is configured)
      website_endpoint = "https://${v.name}.s3-website.${var.region}.scw.cloud"

      # ARN-style identifier for policies
      arn = "arn:scw:s3:::${v.name}"
    }
  }

  # ===========================================================================
  # Region Metadata
  # ---------------------------------------------------------------------------
  # Additional information about the configured region.
  # ===========================================================================

  region_info = {
    "fr-par" = {
      name     = "Paris"
      country  = "France"
      timezone = "Europe/Paris"
    }
    "nl-ams" = {
      name     = "Amsterdam"
      country  = "Netherlands"
      timezone = "Europe/Amsterdam"
    }
    "pl-waw" = {
      name     = "Warsaw"
      country  = "Poland"
      timezone = "Europe/Warsaw"
    }
  }

  current_region_info = local.region_info[var.region]
}
