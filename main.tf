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
  for_each = local.expanded_buckets

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
  tags = merge(var.tags, each.value.tags)

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
# - authenticated-read: Authenticated users can read
# Note: public-read-write is blocked for security reasons
# ==============================================================================

resource "scaleway_object_bucket_acl" "this" {
  for_each = { for k, v in local.expanded_buckets : k => v if v.acl != "private" }

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
  for_each = { for k, v in local.expanded_buckets : k => v if v.website != null }

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

  # bucket_key must reference expanded key (e.g., "data-1" not "data")
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

  # bucket_key must reference expanded key (e.g., "assets-1" not "assets")
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

  # bucket_key must reference expanded key (e.g., "website-1" not "website")
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

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                            BLOCK STORAGE RESOURCES                           ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# Block Storage Volumes
# ------------------------------------------------------------------------------
# Network-attached SSD storage volumes for Scaleway Instances.
# Features:
# - Persistent storage independent of Instance lifecycle
# - Up to 15,000 IOPS for high-performance workloads
# - Can be attached/detached and moved between Instances
# - Supports snapshots for backup and recovery
# - Count parameter for creating multiple identical volumes
#
# IOPS Tiers:
# - 5000 IOPS: Standard performance tier
# - 15000 IOPS: High performance tier (requires compatible Instance)
#
# EXPANDED KEYS:
# When count > 1, volumes are created with expanded keys:
# - database (count=3) → database-1, database-2, database-3
#
# NOTE: prevent_destroy in lifecycle block cannot be dynamically set in
# Terraform. The prevent_destroy variable is for documentation purposes.
# For production, manually set prevent_destroy = true in this block.
# ==============================================================================

resource "scaleway_block_volume" "this" {
  for_each = local.expanded_block_volumes

  name        = each.value.name
  iops        = each.value.iops
  size_in_gb  = each.value.size_in_gb
  zone        = each.value.zone
  project_id  = data.scaleway_account_project.project.id
  snapshot_id = each.value.snapshot_id
  tags        = each.value.tags

  lifecycle {
    # NOTE: Terraform requires this to be a literal value, not a variable.
    # Set to true manually for production volumes to prevent accidental deletion.
    # The prevent_destroy variable in block_volumes serves as documentation of intent.
    prevent_destroy = false
  }
}

# ==============================================================================
# Block Storage Snapshots
# ------------------------------------------------------------------------------
# Point-in-time snapshots of Block Storage volumes.
# Use cases:
# - Regular backups for disaster recovery
# - Creating new volumes from known good state
# - Testing and development environments
# - Migration between zones (via snapshot restore)
# - Export to Object Storage for offsite backup (QCOW2 format)
# - Import from Object Storage to restore from archived snapshots
#
# EXPANDED KEYS:
# When count > 1, snapshots are created with expanded keys:
# - backup (count=3) → backup-1, backup-2, backup-3
#
# TWO MODES:
# 1. From volume: volume_key references an expanded volume key (e.g., "database-1")
# 2. From import: import block specifies QCOW2 file in Object Storage
# ==============================================================================

# Snapshots created from volumes (volume_key provided)
resource "scaleway_block_snapshot" "this" {
  for_each = {
    for k, v in local.expanded_block_snapshots : k => v
    if v.volume_key != null
  }

  name       = each.value.name
  volume_id  = scaleway_block_volume.this[each.value.volume_key].id
  zone       = each.value.zone != null ? each.value.zone : scaleway_block_volume.this[each.value.volume_key].zone
  project_id = data.scaleway_account_project.project.id
  tags       = each.value.tags

  # Export snapshot to Object Storage as QCOW2 file
  dynamic "export" {
    for_each = each.value.export != null ? [each.value.export] : []
    content {
      bucket = export.value.bucket
      key    = export.value.key
    }
  }

  depends_on = [scaleway_block_volume.this]
}

# Snapshots imported from Object Storage (import block provided)
resource "scaleway_block_snapshot" "imported" {
  for_each = {
    for k, v in local.expanded_block_snapshots : k => v
    if v.volume_key == null && v.import != null
  }

  name       = each.value.name
  zone       = each.value.zone != null ? each.value.zone : "${var.region}-1"
  project_id = data.scaleway_account_project.project.id
  tags       = each.value.tags

  # Import snapshot from Object Storage QCOW2 file
  import {
    bucket = each.value.import.bucket
    key    = each.value.import.key
  }

  # Export can also be used with imported snapshots
  dynamic "export" {
    for_each = each.value.export != null ? [each.value.export] : []
    content {
      bucket = export.value.bucket
      key    = export.value.key
    }
  }

  depends_on = [scaleway_object_bucket.this]
}
