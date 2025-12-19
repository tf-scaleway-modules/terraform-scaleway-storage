# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                         SCALEWAY OBJECT STORAGE MODULE                        ║
# ║                                                                                ║
# ║  This module creates and manages Scaleway Object Storage resources:           ║
# ║  - Object buckets with versioning, lifecycle rules, and CORS                  ║
# ║  - Bucket ACL configurations                                                  ║
# ║  - Static website hosting                                                     ║
# ║  - Object lock for WORM compliance                                            ║
# ║  - Bucket policies for access control                                         ║
# ║  - Object uploads                                                             ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# Object Storage Buckets
# ------------------------------------------------------------------------------
# Creates S3-compatible object storage buckets with support for:
# - Versioning: Preserve multiple versions of objects
# - Lifecycle rules: Automate object transitions and expiration
# - CORS: Cross-Origin Resource Sharing for web applications
# - Object Lock: WORM (Write Once Read Many) compliance
# ==============================================================================

resource "scaleway_object_bucket" "this" {
  for_each = var.buckets

  # Core bucket configuration
  name       = each.value.name
  region     = var.region
  project_id = data.scaleway_account_project.project.id

  # Bucket behavior settings
  # force_destroy: When true, bucket can be deleted even if not empty
  # WARNING: Set to false in production to prevent accidental data loss
  force_destroy = each.value.force_destroy

  # Object lock: Enable WORM compliance (cannot be disabled once enabled)
  # Requires versioning to be enabled (automatically enforced)
  object_lock_enabled = each.value.object_lock_enabled

  # Versioning: Keep multiple versions of objects
  # Automatically enabled when object_lock_enabled = true
  versioning {
    enabled = each.value.versioning || each.value.object_lock_enabled
  }

  # ---------------------------------------------------------------------------
  # Lifecycle Rules
  # ---------------------------------------------------------------------------
  # Automate object management:
  # - Transition: Move objects to cheaper storage classes (e.g., GLACIER)
  # - Expiration: Automatically delete objects after specified days
  # - Abort incomplete multipart: Clean up failed uploads
  dynamic "lifecycle_rule" {
    for_each = each.value.lifecycle_rules

    content {
      id      = lifecycle_rule.value.id
      prefix  = lifecycle_rule.value.prefix
      enabled = lifecycle_rule.value.enabled

      # Clean up incomplete multipart uploads after N days
      abort_incomplete_multipart_upload_days = try(
        lifecycle_rule.value.abort_incomplete_multipart_upload.days_after_initiation,
        null
      )

      # Object expiration (permanent deletion)
      dynamic "expiration" {
        for_each = lifecycle_rule.value.expiration != null ? [lifecycle_rule.value.expiration] : []
        content {
          days = expiration.value.days
        }
      }

      # Storage class transitions (e.g., STANDARD -> GLACIER)
      dynamic "transition" {
        for_each = lifecycle_rule.value.transition
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }
    }
  }

  # ---------------------------------------------------------------------------
  # CORS Rules
  # ---------------------------------------------------------------------------
  # Enable cross-origin requests from web browsers
  # Required for JavaScript/AJAX access from different domains
  dynamic "cors_rule" {
    for_each = each.value.cors_rules

    content {
      allowed_headers = cors_rule.value.allowed_headers
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      expose_headers  = cors_rule.value.expose_headers
      max_age_seconds = cors_rule.value.max_age_seconds
    }
  }

  # Tags for resource organization and cost allocation
  tags = concat(var.tags, each.value.tags)

  # Lifecycle meta-argument (Terraform, not S3)
  lifecycle {
    # Set to true in production after initial deployment
    prevent_destroy = false
  }
}

# ==============================================================================
# Bucket ACL Configuration
# ------------------------------------------------------------------------------
# Applies Access Control Lists to buckets with non-private ACLs.
# ACL Types:
# - private: Owner has full control (default, no ACL resource created)
# - public-read: Anyone can read objects
# - public-read-write: Anyone can read/write (use with caution)
# - authenticated-read: Authenticated users can read
# ==============================================================================

resource "scaleway_object_bucket_acl" "this" {
  for_each = { for k, v in var.buckets : k => v if v.acl != "private" }

  bucket     = scaleway_object_bucket.this[each.key].name
  region     = var.region
  project_id = data.scaleway_account_project.project.id
  acl        = each.value.acl

  depends_on = [scaleway_object_bucket.this]
}

# ==============================================================================
# Bucket Website Configuration
# ------------------------------------------------------------------------------
# Enables static website hosting for buckets.
# The bucket will serve HTML content with:
# - Index document: Default page (e.g., index.html)
# - Error document: Custom error page (e.g., 404.html)
#
# Website URL format: https://<bucket-name>.s3-website.<region>.scw.cloud
# ==============================================================================

resource "scaleway_object_bucket_website_configuration" "this" {
  for_each = { for k, v in var.buckets : k => v if v.website != null }

  bucket     = scaleway_object_bucket.this[each.key].name
  region     = var.region
  project_id = data.scaleway_account_project.project.id

  index_document {
    suffix = each.value.website.index_document
  }

  error_document {
    key = each.value.website.error_document
  }

  depends_on = [scaleway_object_bucket.this]
}

# ==============================================================================
# Bucket Lock Configuration (Object Lock / WORM)
# ------------------------------------------------------------------------------
# Configures object lock retention policies for compliance requirements.
# Modes:
# - GOVERNANCE: Users with special permissions can delete/modify
# - COMPLIANCE: No one can delete/modify until retention expires (strict)
#
# IMPORTANT: Object lock must be enabled on bucket creation and cannot be
# disabled afterward. Use with caution as COMPLIANCE mode is irreversible.
# ==============================================================================

resource "scaleway_object_bucket_lock_configuration" "this" {
  for_each = var.bucket_lock_configurations

  bucket     = scaleway_object_bucket.this[each.value.bucket_key].name
  region     = var.region
  project_id = data.scaleway_account_project.project.id

  rule {
    default_retention {
      mode  = each.value.rule.default_retention.mode
      days  = each.value.rule.default_retention.days
      years = each.value.rule.default_retention.years
    }
  }

  depends_on = [scaleway_object_bucket.this]
}

# ==============================================================================
# Bucket Policies
# ------------------------------------------------------------------------------
# IAM-style policies for fine-grained access control.
# Policies use AWS S3-compatible JSON format with:
# - Principal: Who can access (*, specific users)
# - Action: What operations are allowed (s3:GetObject, s3:PutObject, etc.)
# - Resource: Which objects the policy applies to (ARN format)
# - Condition: Optional conditions (IP ranges, request time, etc.)
# ==============================================================================

resource "scaleway_object_bucket_policy" "this" {
  for_each = var.bucket_policies

  bucket     = scaleway_object_bucket.this[each.value.bucket_key].name
  region     = var.region
  project_id = data.scaleway_account_project.project.id
  policy     = each.value.policy

  depends_on = [scaleway_object_bucket.this]
}

# ==============================================================================
# Objects
# ------------------------------------------------------------------------------
# Upload objects (files) to buckets.
# Supports two modes:
# - file: Upload from local filesystem path
# - content: Upload string content directly (useful for config files)
#
# Visibility options:
# - private: Only bucket owner can access (default)
# - public-read: Anyone with URL can download
# ==============================================================================

resource "scaleway_object" "this" {
  for_each = var.objects

  bucket     = scaleway_object_bucket.this[each.value.bucket_key].name
  region     = var.region
  project_id = data.scaleway_account_project.project.id

  key          = each.value.key
  file         = each.value.source
  content      = each.value.content
  content_type = each.value.content_type
  visibility   = each.value.visibility
  tags         = each.value.tags

  depends_on = [scaleway_object_bucket.this]
}
