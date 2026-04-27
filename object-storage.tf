# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                         SCALEWAY OBJECT STORAGE                              ║
# ║                                                                              ║
# ║  S3-compatible buckets with versioning, lifecycle, CORS, website hosting,    ║
# ║  object lock (WORM), bucket policies, and object uploads.                    ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# Object Storage Buckets
# ==============================================================================

resource "scaleway_object_bucket" "this" {
  for_each = local.expanded_buckets

  name       = each.value.name
  region     = var.region
  project_id = data.scaleway_account_project.project.id

  # force_destroy: When true, bucket can be deleted even if not empty.
  # WARNING: Set to false in production to prevent accidental data loss.
  force_destroy = each.value.force_destroy

  # Object lock cannot be disabled once enabled and forces versioning on.
  object_lock_enabled = each.value.object_lock_enabled

  versioning {
    enabled = each.value.versioning || each.value.object_lock_enabled
  }

  dynamic "lifecycle_rule" {
    for_each = each.value.lifecycle_rules

    content {
      id      = lifecycle_rule.value.id
      prefix  = lifecycle_rule.value.prefix
      enabled = lifecycle_rule.value.enabled

      abort_incomplete_multipart_upload_days = try(
        lifecycle_rule.value.abort_incomplete_multipart_upload.days_after_initiation,
        null
      )

      dynamic "expiration" {
        for_each = lifecycle_rule.value.expiration != null ? [lifecycle_rule.value.expiration] : []
        content {
          days = expiration.value.days
        }
      }

      dynamic "transition" {
        for_each = lifecycle_rule.value.transition
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }
    }
  }

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

  tags = merge(var.tags, each.value.tags)

  lifecycle {
    # Set to true in production after initial deployment.
    prevent_destroy = false
  }
}

# ==============================================================================
# Bucket ACL
# ------------------------------------------------------------------------------
# Only created for non-private ACLs. public-read-write is blocked at variable
# validation for security reasons.
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
# Static Website Hosting
# ------------------------------------------------------------------------------
# Website URL: https://<bucket-name>.s3-website.<region>.scw.cloud
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
# Object Lock Configuration (WORM)
# ------------------------------------------------------------------------------
# COMPLIANCE mode is irreversible — no override is possible until retention
# expires, even by the root account.
# ==============================================================================

resource "scaleway_object_bucket_lock_configuration" "this" {
  for_each = var.bucket_lock_configurations

  # bucket_key references an expanded key (e.g., "data-1" not "data").
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
# Scaleway uses Version "2023-04-17" (NOT AWS's "2012-10-17") and bare bucket
# names in Resource (NOT "arn:scw:s3:::"). With 2023-04-17, only explicitly
# allowed actions are permitted.
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
# Either source (local file path) or content (inline string) is required —
# enforced by variable validation.
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
