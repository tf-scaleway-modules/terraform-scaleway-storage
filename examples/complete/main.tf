# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                         COMPLETE EXAMPLE                                      ║
# ║                                                                                ║
# ║  Demonstrates all features of the Scaleway Storage module:                    ║
# ║  - Object Storage: Buckets, versioning, lifecycle, website, CORS              ║
# ║  - Block Storage: Volumes with different IOPS tiers, snapshots                ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# Module Configuration
# ==============================================================================

module "storage" {
  source = "../../"

  # Required: Scaleway organization and project
  organization_id = var.organization_id
  project_name    = var.project_name
  region          = "fr-par"

  # Global tags applied to all resources
  tags = {
    environment = var.environment
    managed-by  = "terraform"
    example     = "complete"
  }

  # ============================================================================
  # Object Storage Buckets
  # ============================================================================

  buckets = {
    # ---------------------------------------------------------------------------
    # Application Data Bucket
    # Private bucket with versioning for data protection
    # ---------------------------------------------------------------------------
    data = {
      name          = "${var.prefix}-data-${var.environment}"
      acl           = "private"
      versioning    = true
      force_destroy = var.environment != "production"

      lifecycle_rules = [
        {
          id      = "cleanup-multipart"
          enabled = true
          abort_incomplete_multipart_upload = {
            days_after_initiation = 7
          }
        }
      ]

      tags = { type = "data" }
    }

    # ---------------------------------------------------------------------------
    # Static Assets Bucket
    # Public bucket with CORS for web applications
    # ---------------------------------------------------------------------------
    assets = {
      name          = "${var.prefix}-assets-${var.environment}"
      acl           = "public-read"
      force_destroy = var.environment != "production"

      cors_rules = [
        {
          allowed_methods = ["GET", "HEAD"]
          allowed_origins = ["*"]
          allowed_headers = ["*"]
          max_age_seconds = 3600
        }
      ]

      tags = { type = "assets" }
    }

    # ---------------------------------------------------------------------------
    # Logs Bucket with Lifecycle
    # Archive to GLACIER after 30 days, delete after 365 days
    # ---------------------------------------------------------------------------
    logs = {
      name          = "${var.prefix}-logs-${var.environment}"
      acl           = "private"
      versioning    = true
      force_destroy = var.environment != "production"

      lifecycle_rules = [
        {
          id      = "archive-and-expire"
          enabled = true
          prefix  = "app/"

          transition = [
            {
              days          = 30
              storage_class = "GLACIER"
            }
          ]

          expiration = {
            days = 365
          }
        }
      ]

      tags = { type = "logs", retention = "1year" }
    }

    # ---------------------------------------------------------------------------
    # Static Website Bucket
    # Hosts static website with index and error pages
    # ---------------------------------------------------------------------------
    website = {
      name          = "${var.prefix}-website-${var.environment}"
      acl           = "public-read"
      force_destroy = var.environment != "production"

      website = {
        index_document = "index.html"
        error_document = "404.html"
      }

      cors_rules = [
        {
          allowed_methods = ["GET", "HEAD"]
          allowed_origins = ["*"]
          allowed_headers = ["*"]
          max_age_seconds = 86400
        }
      ]

      tags = { type = "website" }
    }
  }

  # ============================================================================
  # Object Uploads
  # ============================================================================

  objects = {
    # Upload index.html to website bucket
    website_index = {
      bucket_key   = "website-1" # Expanded key (count defaults to 1)
      key          = "index.html"
      content      = <<-HTML
        <!DOCTYPE html>
        <html>
        <head><title>Welcome</title></head>
        <body><h1>Hello from Scaleway!</h1></body>
        </html>
      HTML
      content_type = "text/html"
      visibility   = "public-read"
    }

    # Upload 404.html to website bucket
    website_404 = {
      bucket_key   = "website-1"
      key          = "404.html"
      content      = <<-HTML
        <!DOCTYPE html>
        <html>
        <head><title>Not Found</title></head>
        <body><h1>404 - Page Not Found</h1></body>
        </html>
      HTML
      content_type = "text/html"
      visibility   = "public-read"
    }

    # Upload robots.txt
    robots = {
      bucket_key   = "website-1"
      key          = "robots.txt"
      content      = "User-agent: *\nAllow: /"
      content_type = "text/plain"
      visibility   = "public-read"
    }
  }

  # ============================================================================
  # Block Storage Volumes
  # ============================================================================

  block_volumes = {
    # ---------------------------------------------------------------------------
    # Database Volume - High Performance
    # 15,000 IOPS for database workloads
    # Creates: database-1
    # ---------------------------------------------------------------------------
    database = {
      name            = "${var.prefix}-db-${var.environment}"
      size_in_gb      = 100
      iops            = 15000 # High performance tier
      zone            = "fr-par-1"
      prevent_destroy = var.environment == "production" # Document intent
      tags            = ["database", var.environment]
    }

    # ---------------------------------------------------------------------------
    # Application Volumes - Standard Performance (count = 2)
    # 5,000 IOPS for general application data
    # Creates: app-1, app-2
    # ---------------------------------------------------------------------------
    app = {
      name       = "${var.prefix}-app-${var.environment}"
      count      = 2 # Create 2 volumes: app-1, app-2
      size_in_gb = 50
      iops       = 5000 # Standard tier
      zone       = "fr-par-1"
      tags       = ["application", var.environment]
    }

    # ---------------------------------------------------------------------------
    # Logs Volume - Standard Performance
    # 5,000 IOPS for log storage
    # Creates: logs-1
    # ---------------------------------------------------------------------------
    logs = {
      name       = "${var.prefix}-logs-vol-${var.environment}"
      size_in_gb = 20
      iops       = 5000
      zone       = "fr-par-1"
      tags       = ["logs", var.environment]
    }
  }

  # ============================================================================
  # Block Storage Snapshots
  # ============================================================================

  block_snapshots = {
    # Create snapshot of database volume AND export to Object Storage
    # Note: volume_key must use expanded key format (database-1, not database)
    database_backup = {
      name       = "${var.prefix}-db-backup-${var.environment}"
      volume_key = "database-1" # Expanded key (count defaults to 1)
      tags       = ["backup", "database", var.environment]

      # Export to Object Storage for offsite backup
      export = {
        bucket = "${var.prefix}-data-${var.environment}" # Use data bucket
        key    = "snapshots/database-backup.qcow2"
      }
    }

    # Create snapshots for app volumes with export (count = 2)
    # Creates: app_backup-1, app_backup-2
    # Exports: snapshots/app-backup-1.qcow2, snapshots/app-backup-2.qcow2
    app_backup = {
      count      = 2
      volume_key = "app-1"
      tags       = ["backup", "app", var.environment]

      # Export each snapshot (key gets -1, -2 suffix automatically)
      export = {
        bucket = "${var.prefix}-data-${var.environment}"
        key    = "snapshots/app-backup.qcow2"
      }
    }
  }

  # Example: Import snapshot from Object Storage (uncomment to use)
  # block_snapshots = {
  #   restored_db = {
  #     name = "restored-database"
  #     zone = "fr-par-1"
  #     tags = ["restored", "database"]
  #
  #     # Import from QCOW2 file in Object Storage
  #     import = {
  #       bucket = "my-backup-bucket"
  #       key    = "snapshots/database-backup.qcow2"
  #     }
  #   }
  # }
}

# ==============================================================================
# Variables
# ==============================================================================

variable "organization_id" {
  description = "Scaleway Organization ID (UUID format)"
  type        = string
}

variable "project_name" {
  description = "Scaleway Project name where resources will be created"
  type        = string
}

variable "prefix" {
  description = "Prefix for resource names (must be globally unique for buckets)"
  type        = string
  default     = "example"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, production)"
  type        = string
  default     = "dev"
}
