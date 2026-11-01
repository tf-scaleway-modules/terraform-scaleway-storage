# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              INPUT VARIABLES                                  ║
# ║                                                                                ║
# ║  All configurable parameters for the Scaleway Object Storage module.          ║
# ║  Variables are organized by category with comprehensive validation.           ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# Project, Region & Zone
# ------------------------------------------------------------------------------
# Where resources are created and billed. Every input defaults to null, which
# keeps the provider's own default project, region and zone.
# ==============================================================================

variable "project_id" {
  description = <<-EOT
    Scaleway Project ID where all resources are created.

    Projects provide logical isolation within an organization.
    When null, the provider's default project is used.

    Format: UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.project_id == null || can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.project_id))
    error_message = "Project ID must be a valid UUID."
  }
}

variable "region" {
  description = <<-EOT
    Scaleway region for Object Storage.

    When null, the provider's default region is used. A default region that
    differs from the one the buckets were created in forces their replacement.

    Available regions:
    - fr-par: Paris, France (Europe)
    - nl-ams: Amsterdam, Netherlands (Europe)
    - pl-waw: Warsaw, Poland (Europe)

    Choose the region closest to your users for optimal latency.
    Data residency requirements may also influence this choice.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.region == null || contains(["fr-par", "nl-ams", "pl-waw"], var.region)
    error_message = "Region must be one of: fr-par, nl-ams, pl-waw."
  }
}

variable "zone" {
  description = <<-EOT
    Default Availability Zone of Block Storage volumes and imported snapshots
    that set no zone of their own (for example fr-par-1).

    When null, the provider's default zone is used. A default zone that differs
    from the one the volumes were created in forces their replacement.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.zone == null || can(regex("^[a-z]{2}-[a-z]{3}-[0-9]$", var.zone))
    error_message = "Zone must be in format: xx-xxx-N (e.g., fr-par-1, nl-ams-1)."
  }
}

variable "tags" {
  description = <<-EOT
    Global tags applied to every taggable resource.

    Buckets and objects receive them merged with their own tags (the per-item
    value wins on a shared key). Block volumes and snapshots take lists of
    strings, so the global tags are added to theirs as "key:value" strings
    without duplicates.

    Common uses:
    - Environment identification (environment = "production")
    - Cost allocation (team = "platform", project = "website")
    - Automation (managed-by = "terraform")

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
    count               : Number of bucket instances to create (default: 1)
    acl                 : Access control - private, public-read, authenticated-read (public-read-write blocked for security)
    force_destroy       : Allow deletion of non-empty bucket (default: false)
    object_lock         : Enable WORM compliance (forces versioning) - cannot be disabled once enabled;
                          set default_retention to apply a retention to new objects
    versioning          : Keep multiple versions of objects
    tags                : Additional tags for this bucket (merged over the global tags)

    SERVER-SIDE ENCRYPTION (default encryption of new objects):
    ───────────────────────────────────────────────────────────
    sse_algorithm      : AES256 (default, SSE-S3) or aws:kms (SSE-KMS)
    kms_master_key_id  : Key Manager key ID (required with aws:kms only)
    bucket_key_enabled : Use bucket keys to reduce SSE-KMS calls

    CORS RULES (for web browser access):
    ────────────────────────────────────
    allowed_headers : Headers allowed in preflight requests (default: ["*"])
    allowed_methods : HTTP methods allowed (GET, PUT, POST, DELETE, HEAD)
    allowed_origins : Origins allowed to make requests
    expose_headers  : Headers exposed to browser
    max_age_seconds : Preflight cache duration (default: 3600)

    OBJECT LOCK (WORM):
    ───────────────────
    object_lock = {
      default_retention = {         # optional; omit for lock without a default retention
        mode  = "GOVERNANCE"        # GOVERNANCE: bypassable with s3:BypassGovernanceRetention
                                    # COMPLIANCE: cannot be overridden by anyone (irreversible!)
        days  = 30                  # exactly one of days (1-36500) or years (1-100)
      }
    }
    WARNING: COMPLIANCE with a long retention can make data permanently immutable.

    LIFECYCLE RULES (automatic object management):
    ──────────────────────────────────────────────
    id         : Unique rule identifier
    enabled    : Whether rule is active (default: true)
    prefix     : Apply to objects with this prefix (empty = all)
    tags       : Apply to objects carrying all these tags (empty = no tag filter)
    expiration : Auto-delete after N days and/or remove expired delete markers
    transition : Move to storage class (STANDARD, GLACIER, ONEZONE_IA) after N days
    noncurrent_version_expiration : Delete noncurrent versions (versioned buckets)
    noncurrent_version_transition : Move noncurrent versions to a storage class
    object_size_greater_than / object_size_less_than : Size filters (bytes)
    abort_incomplete_multipart_upload : Clean up failed uploads

    WEBSITE HOSTING:
    ────────────────
    index_document : Default page (e.g., "index.html")
    error_document : Error page (default: "error.html")
  EOT

  type = map(object({
    # Core bucket settings
    name          = string
    count         = optional(number, 1) # Number of buckets to create (appends -1, -2, etc. to name)
    acl           = optional(string, "private")
    force_destroy = optional(bool, false)
    versioning    = optional(bool, false)
    tags          = optional(map(string), {})

    # WORM: enables object lock (and versioning); default_retention is optional
    object_lock = optional(object({
      default_retention = optional(object({
        mode  = string
        days  = optional(number)
        years = optional(number)
      }))
    }))

    # Default server-side encryption (SSE-S3 or SSE-KMS)
    server_side_encryption = optional(object({
      sse_algorithm      = optional(string, "AES256")
      kms_master_key_id  = optional(string)
      bucket_key_enabled = optional(bool)
    }), null)

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
      tags    = optional(map(string), {})

      # Object size filters, in bytes
      object_size_greater_than = optional(number)
      object_size_less_than    = optional(number)

      expiration = optional(object({
        days                         = optional(number)
        expired_object_delete_marker = optional(bool)
      }), null)

      transition = optional(list(object({
        days          = number
        storage_class = string
      })), [])

      # Noncurrent object versions (versioned buckets)
      noncurrent_version_expiration = optional(object({
        noncurrent_days           = optional(number)
        newer_noncurrent_versions = optional(number)
      }), null)

      noncurrent_version_transition = optional(list(object({
        noncurrent_days           = number
        storage_class             = string
        newer_noncurrent_versions = optional(number)
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

  # Validate ACL values (public-read-write excluded for security)
  validation {
    condition = alltrue([
      for k, v in var.buckets : contains(
        ["private", "public-read", "authenticated-read"],
        v.acl
      )
    ])
    error_message = "ACL must be one of: private, public-read, authenticated-read. Note: public-read-write is blocked for security reasons."
  }

  # Validate bucket naming conventions (S3-compatible)
  validation {
    condition = alltrue([
      for k, v in var.buckets : can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", v.name))
    ])
    error_message = "Bucket name must be 3-63 characters, lowercase alphanumeric with hyphens and dots, start/end with alphanumeric."
  }

  # Validate the final name once the -<n> count suffix is added
  validation {
    condition = alltrue([
      for k, v in var.buckets : v.count == 1 || length(v.name) + 1 + length(tostring(v.count)) <= 63
    ])
    error_message = "Bucket name plus the -<count> suffix must not exceed 63 characters when count > 1."
  }

  # Validate storage class in transitions
  validation {
    condition = alltrue(flatten([
      for k, v in var.buckets : [
        for rule in v.lifecycle_rules : [
          for storage_class in concat(rule.transition[*].storage_class, rule.noncurrent_version_transition[*].storage_class) :
          contains(["STANDARD", "GLACIER", "ONEZONE_IA"], storage_class)
        ]
      ]
    ]))
    error_message = "Storage class must be one of: STANDARD, GLACIER, ONEZONE_IA."
  }

  # Validate server-side encryption
  validation {
    condition = alltrue([
      for k, v in var.buckets : v.server_side_encryption == null || (
        contains(["AES256", "aws:kms"], v.server_side_encryption.sse_algorithm) &&
        (v.server_side_encryption.sse_algorithm == "aws:kms") == (v.server_side_encryption.kms_master_key_id != null)
      )
    ])
    error_message = "server_side_encryption.sse_algorithm must be AES256 or aws:kms, and kms_master_key_id must be set with aws:kms only."
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

  # Validate count is at least 1
  validation {
    condition = alltrue([
      for k, v in var.buckets : v.count >= 1
    ])
    error_message = "Bucket count must be at least 1."
  }

  # Validate lock mode
  validation {
    condition = alltrue([
      for k, v in var.buckets :
      v.object_lock == null || v.object_lock.default_retention == null || contains(["GOVERNANCE", "COMPLIANCE"], v.object_lock.default_retention.mode)
    ])
    error_message = "Lock mode must be either GOVERNANCE or COMPLIANCE."
  }

  # Validate exactly one of days/years is specified
  validation {
    condition = alltrue([
      for k, v in var.buckets :
      v.object_lock == null || v.object_lock.default_retention == null || (v.object_lock.default_retention.days != null) != (v.object_lock.default_retention.years != null)
    ])
    error_message = "Exactly one of 'days' or 'years' must be specified for retention period."
  }

  # Validate retention period ranges
  validation {
    condition = alltrue([
      for k, v in var.buckets :
      v.object_lock == null || v.object_lock.default_retention == null || (
        (v.object_lock.default_retention.days == null || (v.object_lock.default_retention.days >= 1 && v.object_lock.default_retention.days <= 36500)) &&
        (v.object_lock.default_retention.years == null || (v.object_lock.default_retention.years >= 1 && v.object_lock.default_retention.years <= 100))
      )
    ])
    error_message = "Retention days must be 1-36500, years must be 1-100."
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

    POLICY DOCUMENT FORMAT (Scaleway S3-compatible):
    ────────────────────────────────────────────────
    {
      "Version": "2023-04-17",
      "Id": "MyPolicy",
      "Statement": [
        {
          "Sid": "UniqueStatementId",
          "Effect": "Allow",
          "Principal": "*" | { "SCW": "user_id:<USER_ID>" },
          "Action": ["s3:GetObject", "s3:PutObject", ...],
          "Resource": ["<bucket-name>/*"]
        }
      ]
    }

    IMPORTANT NOTES:
    ────────────────
    - Use Version "2023-04-17" (Scaleway's current version, NOT AWS's "2012-10-17")
    - Resource format is "<bucket-name>/*" (NOT "arn:scw:s3:::bucket-name/*")
    - With 2023-04-17, only explicitly allowed actions are permitted (implicit deny)
    - A policy with only Principal:"*" will block your Terraform user from managing the bucket
    - Always include your user_id/application_id with full S3 permissions

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

  # Validate bucket_key is an expanded key of var.buckets
  validation {
    condition = alltrue([
      for k, v in var.bucket_policies : contains(flatten([for bk, b in var.buckets : [for i in range(1, b.count + 1) : "${bk}-${i}"]]), v.bucket_key)
    ])
    error_message = "bucket_key must be an expanded key of var.buckets (for example data-1)."
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
    tags         : Object-level tags (merged over the global tags)
    hash         : (Optional) Triggers a re-upload when it changes; use filemd5(path)
                   with source so a modified file is uploaded again
    storage_class: (Optional) STANDARD, GLACIER or ONEZONE_IA (provider default if unset)
    metadata     : (Optional) Map of object metadata; keys must be lowercase

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
    bucket_key    = string
    key           = string
    source        = optional(string)
    content       = optional(string)
    content_type  = optional(string)
    visibility    = optional(string, "private")
    tags          = optional(map(string), {})
    hash          = optional(string)
    storage_class = optional(string)
    metadata      = optional(map(string))
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

  # Validate storage class when set
  validation {
    condition = alltrue([
      for k, v in var.objects :
      v.storage_class == null || contains(["STANDARD", "GLACIER", "ONEZONE_IA"], v.storage_class)
    ])
    error_message = "Object storage_class must be one of: STANDARD, GLACIER, ONEZONE_IA."
  }

  # Validate metadata keys (the provider requires lowercase keys)
  validation {
    condition = alltrue([
      for k, v in var.objects :
      v.metadata == null || alltrue([for mk in keys(v.metadata) : mk == lower(mk)])
    ])
    error_message = "Object metadata keys must be lowercase."
  }

  # Validate bucket_key is an expanded key of var.buckets
  validation {
    condition = alltrue([
      for k, v in var.objects : contains(flatten([for bk, b in var.buckets : [for i in range(1, b.count + 1) : "${bk}-${i}"]]), v.bucket_key)
    ])
    error_message = "bucket_key must be an expanded key of var.buckets (for example data-1)."
  }
}

# ==============================================================================
# Block Storage Volumes Configuration
# ------------------------------------------------------------------------------
# Network-attached SSD storage volumes that can be attached to Instances.
# Supports high-performance workloads with up to 15,000 IOPS.
# ==============================================================================

variable "block_volumes" {
  description = <<-EOT
    Map of Block Storage volumes to create.

    Block volumes are network-attached SSD storage that can be attached to
    Scaleway Instances. They persist independently of Instances and can be
    moved between Instances in the same Availability Zone.

    VOLUME CONFIGURATION:
    ─────────────────────
    name            : (Optional) Volume name, auto-generated if not provided
    count           : (Optional) Number of volume instances to create (default: 1)
    size_in_gb      : (Required unless snapshot_id is set) Volume size in GB (minimum 5 GB);
                      a volume restored from a snapshot takes the snapshot size when unset
    iops            : (Required) IOPS performance tier - 5000 or 15000
    zone            : (Optional) Availability Zone (defaults to var.zone, then the provider default zone)
    snapshot_id     : (Optional) Create volume from existing snapshot
    tags            : (Optional) List of tags for the volume (global tags are added as "key:value")

    IOPS TIERS:
    ───────────
    5000  : Standard performance, suitable for most workloads
    15000 : High performance, for databases and I/O intensive applications
            Requires Instance with at least 3 GiB/s block bandwidth

    EXPANDED KEYS:
    ──────────────
    When count > 1, volumes are created with expanded keys:
    - count = 1 → volume-1
    - count = 3 → volume-1, volume-2, volume-3

    IMPORTANT NOTES:
    ────────────────
    - IOPS cannot be changed after volume creation
    - Volume must be in same zone as Instance to attach
    - Minimum size is 5 GB
    - Protect production volumes with plan review and least-privilege credentials
  EOT

  type = map(object({
    name        = optional(string)
    count       = optional(number, 1)
    size_in_gb  = optional(number)
    iops        = number
    zone        = optional(string)
    snapshot_id = optional(string)
    tags        = optional(list(string), [])
  }))

  default = {}

  # Validate IOPS values
  validation {
    condition = alltrue([
      for k, v in var.block_volumes : contains([5000, 15000], v.iops)
    ])
    error_message = "Block volume IOPS must be either 5000 or 15000."
  }

  # Validate the size is given unless a snapshot provides it
  validation {
    condition = alltrue([
      for k, v in var.block_volumes : v.size_in_gb != null || v.snapshot_id != null
    ])
    error_message = "Block volume size_in_gb is required unless snapshot_id is set."
  }

  # Validate minimum size
  validation {
    condition = alltrue([
      for k, v in var.block_volumes : v.size_in_gb == null || v.size_in_gb >= 5
    ])
    error_message = "Block volume size must be at least 5 GB."
  }

  # Validate zone format
  validation {
    condition = alltrue([
      for k, v in var.block_volumes : v.zone == null || can(regex("^[a-z]{2}-[a-z]{3}-[0-9]$", v.zone))
    ])
    error_message = "Zone must be in format: xx-xxx-N (e.g., fr-par-1, nl-ams-1)."
  }

  # Validate count is at least 1
  validation {
    condition = alltrue([
      for k, v in var.block_volumes : v.count >= 1
    ])
    error_message = "Block volume count must be at least 1."
  }
}

# ==============================================================================
# Block Storage Snapshots Configuration
# ------------------------------------------------------------------------------
# Point-in-time snapshots of Block Storage volumes for backup and recovery.
# ==============================================================================

variable "block_snapshots" {
  description = <<-EOT
    Map of Block Storage snapshots to create.

    Snapshots are point-in-time copies of Block Storage volumes.
    Use for backups, disaster recovery, or creating new volumes.

    SNAPSHOT CONFIGURATION:
    ───────────────────────
    name       : (Optional) Snapshot name, auto-generated if not provided
    count      : (Optional) Number of snapshot instances to create (default: 1)
    volume_key : (Required if no import) Reference to expanded volume key (e.g., "database-1")
    zone       : (Optional) Availability Zone (from-volume: the volume's zone; imported: var.zone,
                 then the provider default zone)
    tags       : (Optional) Tags for the snapshot (global tags are added as "key:value")
    timeouts   : (Optional) create/read/update/delete durations such as "30m" or "1h30m"
                 (provider default 5m each); raise create for large exports and imports

    EXPORT TO OBJECT STORAGE:
    ─────────────────────────
    Export snapshots as QCOW2 files to Object Storage for offsite backup.
    export = {
      bucket = "my-backup-bucket"   # Bucket name (must exist)
      key    = "snapshots/db.qcow2" # Object key/path
    }

    IMPORT FROM OBJECT STORAGE:
    ───────────────────────────
    Create snapshot from QCOW2 file in Object Storage (instead of volume).
    import = {
      bucket = "my-backup-bucket"   # Bucket name
      key    = "snapshots/db.qcow2" # Object key/path
    }
    Note: When using import, volume_key is not required.

    EXPANDED KEYS:
    ──────────────
    When count > 1, snapshots are created with expanded keys:
    - count = 1 → snapshot-1
    - count = 3 → snapshot-1, snapshot-2, snapshot-3

    USE CASES:
    ──────────
    - Regular backups exported to Object Storage
    - Disaster recovery with offsite QCOW2 files
    - Cross-zone/region migration via Object Storage
    - Creating volumes from archived snapshots
  EOT

  type = map(object({
    name       = optional(string)
    count      = optional(number, 1)
    volume_key = optional(string) # Required if no import block
    zone       = optional(string)
    tags       = optional(list(string), [])

    # Operation timeouts, applied to every snapshot of the entry
    timeouts = optional(object({
      create = optional(string)
      read   = optional(string)
      update = optional(string)
      delete = optional(string)
    }))

    # Export snapshot to Object Storage as QCOW2
    export = optional(object({
      bucket = string # Bucket name to export to
      key    = string # Object key/path (e.g., "backups/snapshot.qcow2")
    }))

    # Import snapshot from Object Storage QCOW2 (alternative to volume_key)
    import = optional(object({
      bucket = string # Bucket name to import from
      key    = string # Object key/path (e.g., "backups/snapshot.qcow2")
    }))
  }))

  default = {}

  # Validate volume_key is provided when not importing
  validation {
    condition = alltrue([
      for k, v in var.block_snapshots :
      v.volume_key != null || v.import != null
    ])
    error_message = "Either volume_key or import block must be specified for each snapshot."
  }

  # Validate volume_key is an expanded key of var.block_volumes
  validation {
    condition = alltrue([
      for k, v in var.block_snapshots :
      v.volume_key == null || contains(flatten([for vk, b in var.block_volumes : [for i in range(1, b.count + 1) : "${vk}-${i}"]]), v.volume_key)
    ])
    error_message = "volume_key must be an expanded key of var.block_volumes (for example db-1)."
  }

  # Validate volume_key format when provided
  validation {
    condition = alltrue([
      for k, v in var.block_snapshots :
      v.volume_key == null || can(regex("^[a-zA-Z][a-zA-Z0-9_-]*$", v.volume_key))
    ])
    error_message = "Volume key must be a valid identifier (alphanumeric with underscores/hyphens, starting with letter)."
  }

  # Validate count is at least 1
  validation {
    condition = alltrue([
      for k, v in var.block_snapshots : v.count >= 1
    ])
    error_message = "Block snapshot count must be at least 1."
  }

  # Validate timeouts are Go durations
  validation {
    condition = alltrue([
      for k, v in var.block_snapshots :
      v.timeouts == null || alltrue([
        for t in values(v.timeouts) : t == null || can(regex("^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$", t))
      ])
    ])
    error_message = "Snapshot timeouts must be durations such as 10m or 1h30m (units ns, us, ms, s, m, h)."
  }

  # Validate export key ends with .qcow or .qcow2
  validation {
    condition = alltrue([
      for k, v in var.block_snapshots :
      v.export == null || can(regex("\\.(qcow2?|QCOW2?)$", v.export.key))
    ])
    error_message = "Export key must end with .qcow or .qcow2 extension."
  }

  # Validate import key ends with .qcow or .qcow2
  validation {
    condition = alltrue([
      for k, v in var.block_snapshots :
      v.import == null || can(regex("\\.(qcow2?|QCOW2?)$", v.import.key))
    ])
    error_message = "Import key must end with .qcow or .qcow2 extension."
  }
}
