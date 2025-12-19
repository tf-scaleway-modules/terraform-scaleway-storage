# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              LOCAL VALUES                                     ║
# ║                                                                                ║
# ║  Computed values and transformations used throughout the module.              ║
# ║  These simplify resource configurations and output formatting.                ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

locals {
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
