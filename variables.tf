# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              INPUT VARIABLES                                  ║
# ║                                                                                ║
# ║  All configurable parameters for the Scaleway Object Storage module.          ║
# ║  Variables are organized by category with comprehensive validation.           ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# Organization & Project
# ------------------------------------------------------------------------------
# Required identifiers for Scaleway resource organization.
# These determine where resources are created and billed.
# ==============================================================================

variable "organization_id" {
  description = <<-EOT
    Scaleway Organization ID.

    The organization is the top-level entity in Scaleway's hierarchy.
    Find this in the Scaleway Console under Organization Settings.

    Format: UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
  EOT
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.organization_id))
    error_message = "Organization ID must be a valid UUID format."
  }
}

variable "project_name" {
  description = <<-EOT
    Scaleway Project name where all resources will be created.

    Projects provide logical isolation within an organization.
    All buckets, objects, and policies will be created in this project.

    Naming rules:
    - Must start with a lowercase letter
    - Can contain lowercase letters, numbers, and hyphens
    - Must be 2-63 characters long
  EOT
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,61}[a-z0-9]$", var.project_name))
    error_message = "Project name must be lowercase alphanumeric with hyphens, start with a letter, and be 2-63 characters."
  }
}

# ==============================================================================
# Global Configuration
# ------------------------------------------------------------------------------
# Settings that apply to all resources created by this module.
# ==============================================================================

variable "region" {
  description = <<-EOT
    Scaleway region for object storage.

    Available regions:
    - fr-par: Paris, France (Europe)
    - nl-ams: Amsterdam, Netherlands (Europe)
    - pl-waw: Warsaw, Poland (Europe)

    Choose the region closest to your users for optimal latency.
    Data residency requirements may also influence this choice.
  EOT
  type        = string
  default     = "fr-par"

  validation {
    condition     = contains(["fr-par", "nl-ams", "pl-waw"], var.region)
    error_message = "Region must be one of: fr-par, nl-ams, pl-waw."
  }
}

variable "tags" {
  description = <<-EOT
    Global tags applied to all resources.

    Tags are key-value pairs for organizing and categorizing resources.
    Common uses:
    - Environment identification (environment:production)
    - Cost allocation (team:platform, project:website)
    - Automation (managed-by:terraform)

    Format: Map of strings (e.g., {env = "prod", team = "devops"})
  EOT
  type        = map(string)
  default     = {}
}

# ==============================================================================
# Object Buckets Configuration
# ------------------------------------------------------------------------------
# Main configuration for creating object storage buckets.
# Each bucket can have its own ACL, lifecycle rules, CORS, and website config.
# ==============================================================================

variable "buckets" {
  description = <<-EOT
    Map of object storage buckets to create.

    Each bucket key becomes a reference for other resources (policies, objects).
    Bucket names must be globally unique across all Scaleway users.

    BUCKET CONFIGURATION OPTIONS:
    ─────────────────────────────
    name                : (Required) Globally unique bucket name
    acl                 : Access control - private, public-read, public-read-write, authenticated-read
    force_destroy       : Allow deletion of non-empty bucket (default: false)
    object_lock_enabled : Enable WORM compliance - cannot be disabled once enabled
    versioning          : Keep multiple versions of objects
    tags                : Additional tags for this bucket

    CORS RULES (for web browser access):
    ────────────────────────────────────
    allowed_headers : Headers allowed in preflight requests (default: ["*"])
    allowed_methods : HTTP methods allowed (GET, PUT, POST, DELETE, HEAD)
    allowed_origins : Origins allowed to make requests
    expose_headers  : Headers exposed to browser
    max_age_seconds : Preflight cache duration (default: 3600)

    LIFECYCLE RULES (automatic object management):
    ──────────────────────────────────────────────
    id         : Unique rule identifier
    enabled    : Whether rule is active (default: true)
    prefix     : Apply to objects with this prefix (empty = all)
    expiration : Auto-delete after N days
    transition : Move to storage class (GLACIER, ONEZONE_IA) after N days
    abort_incomplete_multipart_upload : Clean up failed uploads

    WEBSITE HOSTING:
    ────────────────
    index_document : Default page (e.g., "index.html")
    error_document : Error page (default: "error.html")
  EOT

  type = map(object({
    # Core bucket settings
    name                = string
    acl                 = optional(string, "private")
    force_destroy       = optional(bool, false)
    object_lock_enabled = optional(bool, false)
    versioning          = optional(bool, false)
    tags                = optional(map(string), {})

    # CORS configuration for web access
    cors_rules = optional(list(object({
      allowed_headers = optional(list(string), ["*"])
      allowed_methods = list(string)
      allowed_origins = list(string)
      expose_headers  = optional(list(string), [])
      max_age_seconds = optional(number, 3600)
    })), [])

    # Lifecycle management rules
    lifecycle_rules = optional(list(object({
      id      = string
      enabled = optional(bool, true)
      prefix  = optional(string, "")

      expiration = optional(object({
        days = number
      }), null)

      transition = optional(list(object({
        days          = number
        storage_class = string
      })), [])

      abort_incomplete_multipart_upload = optional(object({
        days_after_initiation = number
      }), null)
    })), [])

    # Static website configuration
    website = optional(object({
      index_document = string
      error_document = optional(string, "error.html")
    }), null)
  }))

  default = {}

  # Validate ACL values
  validation {
    condition = alltrue([
      for k, v in var.buckets : contains(
        ["private", "public-read", "public-read-write", "authenticated-read"],
        v.acl
      )
    ])
    error_message = "ACL must be one of: private, public-read, public-read-write, authenticated-read."
  }

  # Validate bucket naming conventions (S3-compatible)
  validation {
    condition = alltrue([
      for k, v in var.buckets : can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", v.name))
    ])
    error_message = "Bucket name must be 3-63 characters, lowercase alphanumeric with hyphens and dots, start/end with alphanumeric."
  }

  # Validate storage class in transitions
  validation {
    condition = alltrue(flatten([
      for k, v in var.buckets : [
        for rule in v.lifecycle_rules : [
          for transition in rule.transition :
          contains(["GLACIER", "ONEZONE_IA", "STANDARD_IA"], transition.storage_class)
        ]
      ]
    ]))
    error_message = "Storage class must be one of: GLACIER, ONEZONE_IA, STANDARD_IA."
  }

  # Validate CORS methods
  validation {
    condition = alltrue(flatten([
      for k, v in var.buckets : [
        for rule in v.cors_rules : [
          for method in rule.allowed_methods :
          contains(["GET", "PUT", "POST", "DELETE", "HEAD"], method)
        ]
      ]
    ]))
    error_message = "CORS allowed_methods must be one of: GET, PUT, POST, DELETE, HEAD."
  }
}

# ==============================================================================
# Bucket Policies Configuration
# ------------------------------------------------------------------------------
# IAM-style policies for fine-grained bucket access control.
# Use instead of ACLs for complex access requirements.
# ==============================================================================

variable "bucket_policies" {
  description = <<-EOT
    Map of bucket policies to apply.

    Policies provide fine-grained access control using IAM-style JSON documents.
    More flexible than ACLs for complex access patterns.

    POLICY STRUCTURE:
    ─────────────────
    bucket_key : Reference to bucket key in var.buckets
    policy     : JSON policy document (use jsonencode() for safety)

    POLICY DOCUMENT FORMAT (AWS S3-compatible):
    ───────────────────────────────────────────
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Sid": "UniqueStatementId",
          "Effect": "Allow" | "Deny",
          "Principal": "*" | { "SCW": ["user_id"] },
          "Action": ["s3:GetObject", "s3:PutObject", ...],
          "Resource": ["arn:scw:s3:::bucket-name/*"],
          "Condition": { ... }  // Optional
        }
      ]
    }

    COMMON ACTIONS:
    ───────────────
    s3:GetObject       - Download objects
    s3:PutObject       - Upload objects
    s3:DeleteObject    - Delete objects
    s3:ListBucket      - List bucket contents
    s3:GetBucketPolicy - Read bucket policy
  EOT

  type = map(object({
    bucket_key = string
    policy     = string
  }))

  default = {}

  # Validate bucket_key references exist
  validation {
    condition = alltrue([
      for k, v in var.bucket_policies : can(regex("^[a-zA-Z][a-zA-Z0-9_-]*$", v.bucket_key))
    ])
    error_message = "Bucket key must be a valid identifier (alphanumeric with underscores/hyphens, starting with letter)."
  }
}

# ==============================================================================
# Object Lock Configuration
# ------------------------------------------------------------------------------
# WORM (Write Once Read Many) compliance settings.
# Used for regulatory compliance, legal holds, and data protection.
# ==============================================================================

variable "bucket_lock_configurations" {
  description = <<-EOT
    Map of object lock configurations for WORM compliance.

    Object lock prevents object deletion or modification for a retention period.
    IMPORTANT: The bucket must have object_lock_enabled = true.

    LOCK MODES:
    ───────────
    GOVERNANCE  : Can be overridden by users with s3:BypassGovernanceRetention permission
    COMPLIANCE  : Cannot be overridden by anyone, including root account (irreversible!)

    RETENTION PERIOD (specify exactly one):
    ───────────────────────────────────────
    days  : Number of days to retain (1-36500)
    years : Number of years to retain (1-100)

    WARNING: COMPLIANCE mode with long retention can make data permanently
    immutable. Test thoroughly in non-production environments first.
  EOT

  type = map(object({
    bucket_key = string
    rule = object({
      default_retention = object({
        mode  = string
        days  = optional(number)
        years = optional(number)
      })
    })
  }))

  default = {}

  # Validate lock mode
  validation {
    condition = alltrue([
      for k, v in var.bucket_lock_configurations :
      contains(["GOVERNANCE", "COMPLIANCE"], v.rule.default_retention.mode)
    ])
    error_message = "Lock mode must be either GOVERNANCE or COMPLIANCE."
  }

  # Validate exactly one of days/years is specified
  validation {
    condition = alltrue([
      for k, v in var.bucket_lock_configurations :
      (v.rule.default_retention.days != null) != (v.rule.default_retention.years != null)
    ])
    error_message = "Exactly one of 'days' or 'years' must be specified for retention period."
  }

  # Validate retention period ranges
  validation {
    condition = alltrue([
      for k, v in var.bucket_lock_configurations :
      (v.rule.default_retention.days == null || (v.rule.default_retention.days >= 1 && v.rule.default_retention.days <= 36500)) &&
      (v.rule.default_retention.years == null || (v.rule.default_retention.years >= 1 && v.rule.default_retention.years <= 100))
    ])
    error_message = "Retention days must be 1-36500, years must be 1-100."
  }
}

# ==============================================================================
# Objects Configuration
# ------------------------------------------------------------------------------
# Upload objects (files) to buckets during infrastructure provisioning.
# Useful for initial configuration files, static assets, or seed data.
# ==============================================================================

variable "objects" {
  description = <<-EOT
    Map of objects to upload to buckets.

    Objects can be uploaded from local files or inline content.
    Use for configuration files, static assets, or initial seed data.

    OBJECT CONFIGURATION:
    ─────────────────────
    bucket_key   : Reference to bucket key in var.buckets
    key          : Object path in bucket (e.g., "images/logo.png")
    source       : Local file path (mutually exclusive with content)
    content      : Inline string content (mutually exclusive with source)
    content_type : MIME type (auto-detected if not specified)
    visibility   : private (default) or public-read
    tags         : Object-level tags

    COMMON MIME TYPES:
    ──────────────────
    text/html              - HTML files
    text/css               - CSS stylesheets
    text/javascript        - JavaScript files
    application/json       - JSON data
    image/png, image/jpeg  - Images
    application/pdf        - PDF documents
  EOT

  type = map(object({
    bucket_key   = string
    key          = string
    source       = optional(string)
    content      = optional(string)
    content_type = optional(string)
    visibility   = optional(string, "private")
    tags         = optional(map(string), {})
  }))

  default = {}

  # Validate exactly one of source/content is specified
  validation {
    condition = alltrue([
      for k, v in var.objects :
      (v.source != null) != (v.content != null)
    ])
    error_message = "Exactly one of 'source' or 'content' must be specified for each object."
  }

  # Validate visibility
  validation {
    condition = alltrue([
      for k, v in var.objects :
      contains(["private", "public-read"], v.visibility)
    ])
    error_message = "Object visibility must be either 'private' or 'public-read'."
  }

  # Validate object key format
  validation {
    condition = alltrue([
      for k, v in var.objects :
      !startswith(v.key, "/") && length(v.key) > 0 && length(v.key) <= 1024
    ])
    error_message = "Object key must not start with '/', must be 1-1024 characters."
  }
}
