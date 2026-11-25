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
  description = "Scaleway Project ID (UUID) where all resources are created. When `null`, the provider default project is used."
  type        = string
  default     = null

  validation {
    condition     = var.project_id == null || can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.project_id))
    error_message = "Project ID must be a valid UUID."
  }
}

variable "region" {
  description = "Scaleway region for Object Storage: `fr-par`, `nl-ams` or `pl-waw`. When `null`, the provider default region is used; a default that differs from the one the buckets were created in forces their replacement."
  type        = string
  default     = null

  validation {
    condition     = var.region == null || contains(["fr-par", "nl-ams", "pl-waw"], var.region)
    error_message = "Region must be one of: fr-par, nl-ams, pl-waw."
  }
}

variable "zone" {
  description = "Default Availability Zone (for example `fr-par-1`) of Block Storage volumes and imported snapshots that set no zone of their own. When `null`, the provider default zone is used; a default that differs from the one the volumes were created in forces their replacement."
  type        = string
  default     = null

  validation {
    condition     = var.zone == null || can(regex("^[a-z]{2}-[a-z]{3}-[0-9]$", var.zone))
    error_message = "Zone must be in format: xx-xxx-N (e.g., fr-par-1, nl-ams-1)."
  }
}

variable "tags" {
  description = "Global tags applied to every taggable resource, as a map of strings (for example `env` and `team`). Buckets and objects merge them with their own tags (the per-item value wins); block volumes and snapshots get them added as `key:value` strings without duplicates."
  type        = map(string)
  default     = {}
}

variable "buckets" {
  description = "Map of object storage buckets to create, keyed by a stable reference used by `objects` and `bucket_policies` (in expanded form, for example `data-1`). Bucket names must be globally unique. See Bucket Configuration Reference in the README for every attribute."

  type = map(object({
    name          = string
    count         = optional(number, 1)
    acl           = optional(string, "private")
    force_destroy = optional(bool, false)
    versioning    = optional(bool, false)
    tags          = optional(map(string), {})

    object_lock = optional(object({
      default_retention = optional(object({
        mode  = string
        days  = optional(number)
        years = optional(number)
      }))
    }))

    server_side_encryption = optional(object({
      sse_algorithm      = optional(string, "AES256")
      kms_master_key_id  = optional(string)
      bucket_key_enabled = optional(bool)
    }), null)

    cors_rules = optional(list(object({
      allowed_headers = optional(list(string), ["*"])
      allowed_methods = list(string)
      allowed_origins = list(string)
      expose_headers  = optional(list(string), [])
      max_age_seconds = optional(number, 3600)
    })), [])

    lifecycle_rules = optional(list(object({
      id      = string
      enabled = optional(bool, true)
      prefix  = optional(string, "")
      tags    = optional(map(string), {})

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
  description = "Map of IAM-style bucket policies, each entry holding the expanded `bucket_key` of a bucket in `buckets` and a JSON `policy` document. See Bucket Policies in the README for the document format and pitfalls."

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
  description = "Map of objects to upload to buckets from a local `source` file or inline `content` (exactly one of the two). Each entry holds the expanded `bucket_key` and the object `key`. See Objects in the README for every attribute."

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
  description = "Map of Block Storage volumes to create, keyed by a stable reference; with `count` above 1 the keys become `<key>-1`, `<key>-2`, and so on. Volumes persist independently of Instances. See Block Storage Configuration Reference in the README for every attribute."

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
  description = "Map of Block Storage snapshots to create, keyed by a stable reference; with `count` above 1 the keys become `<key>-1`, `<key>-2`, and so on. Each snapshot comes from an expanded `volume_key` or from an `import`, and can be exported to Object Storage. See Block Storage Configuration Reference in the README for every attribute."

  type = map(object({
    name       = optional(string)
    count      = optional(number, 1)
    volume_key = optional(string)
    zone       = optional(string)
    tags       = optional(list(string), [])

    timeouts = optional(object({
      create = optional(string)
      read   = optional(string)
      update = optional(string)
      delete = optional(string)
    }))

    export = optional(object({
      bucket = string
      key    = string
    }))

    import = optional(object({
      bucket = string
      key    = string
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
