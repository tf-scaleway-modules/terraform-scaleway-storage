# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                         COMPLETE EXAMPLE                                      ║
# ║                                                                                ║
# ║  Demonstrates all features of the Scaleway Object Storage module:             ║
# ║  - Multiple buckets with different configurations                             ║
# ║  - Lifecycle rules for cost optimization                                      ║
# ║  - Static website hosting with CORS                                           ║
# ║  - Bucket policies for access control                                         ║
# ║  - Object uploads                                                             ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# Module Configuration
# ==============================================================================

module "storage" {
  source = "../../"

  # Required: Scaleway organization and project
  organization_id = var.organization_id
  project_name    = var.project_name

  # Region and global tags
  region = "fr-par"
  tags = {
    environment = var.environment
    managed-by  = "terraform"
  }

  # ---------------------------------------------------------------------------
  # Bucket Configurations
  # ---------------------------------------------------------------------------

  buckets = {
    # -------------------------------------------------------------------------
    # Private Data Bucket
    # -------------------------------------------------------------------------
    # For application data with versioning and lifecycle management
    data = {
      name          = "${var.prefix}-data-${var.environment}"
      acl           = "private"
      versioning    = true
      force_destroy = var.environment != "production"

      lifecycle_rules = [
        {
          id      = "archive-logs"
          enabled = true
          prefix  = "logs/"

          # Move logs to GLACIER after 30 days
          transition = [
            {
              days          = 30
              storage_class = "GLACIER"
            }
          ]

          # Delete logs after 1 year
          expiration = {
            days = 365
          }

          # Clean up incomplete uploads
          abort_incomplete_multipart_upload = {
            days_after_initiation = 7
          }
        },
        {
          id      = "cleanup-temp"
          enabled = true
          prefix  = "temp/"

          # Delete temporary files after 7 days
          expiration = {
            days = 7
          }
        }
      ]

      tags = { type = "data" }
    }

    # -------------------------------------------------------------------------
    # Public Assets Bucket
    # -------------------------------------------------------------------------
    # For static assets served via CDN or direct access
    assets = {
      name          = "${var.prefix}-assets-${var.environment}"
      acl           = "public-read"
      force_destroy = var.environment != "production"

      # Enable CORS for web applications
      cors_rules = [
        {
          allowed_methods = ["GET", "HEAD"]
          allowed_origins = ["*"]
          allowed_headers = ["*"]
          expose_headers  = ["ETag", "Content-Length"]
          max_age_seconds = 86400 # 24 hours
        }
      ]

      tags = { type = "assets", public = "true" }
    }

    # -------------------------------------------------------------------------
    # Static Website Bucket
    # -------------------------------------------------------------------------
    # For hosting static websites
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
          max_age_seconds = 3600
        }
      ]

      tags = { type = "website", public = "true" }
    }

    # -------------------------------------------------------------------------
    # Backup Bucket
    # -------------------------------------------------------------------------
    # For backups with versioning (never force_destroy)
    backup = {
      name          = "${var.prefix}-backup-${var.environment}"
      acl           = "private"
      versioning    = true
      force_destroy = false # Never allow force destroy for backups

      lifecycle_rules = [
        {
          id      = "cleanup-multipart"
          enabled = true

          # Clean up failed multipart uploads quickly
          abort_incomplete_multipart_upload = {
            days_after_initiation = 1
          }
        }
      ]

      tags = { type = "backup", critical = "true" }
    }

    # -------------------------------------------------------------------------
    # Compliance Bucket (Optional - Uncomment if needed)
    # -------------------------------------------------------------------------
    # For regulatory compliance with WORM (Write Once Read Many)
    # WARNING: Object lock cannot be disabled once enabled!
    #
    # compliance = {
    #   name                = "${var.prefix}-compliance-${var.environment}"
    #   acl                 = "private"
    #   versioning          = true    # Required for object lock
    #   object_lock_enabled = true    # Enable WORM
    #   force_destroy       = false
    #   tags                = { type = "compliance", retention = "enabled" }
    # }
  }

  # ---------------------------------------------------------------------------
  # Bucket Policies (Optional)
  # ---------------------------------------------------------------------------
  # Note: For simple public access, use ACL (acl = "public-read") instead.
  # Bucket policies with Version 2023-04-17 require explicit permissions for
  # ALL operations - a policy with only s3:GetObject will block Terraform from
  # managing the bucket. Only use policies when you need fine-grained control
  # and can specify your user_id/application_id as Principal.
  #
  # Example policy structure (requires your SCW user_id or application_id):
  # bucket_policies = {
  #   assets_policy = {
  #     bucket_key = "assets"
  #     policy = jsonencode({
  #       Version = "2023-04-17"
  #       Statement = [
  #         {
  #           Sid       = "TerraformAccess"
  #           Effect    = "Allow"
  #           Principal = { SCW = "user_id:<YOUR_USER_ID>" }
  #           Action    = "s3:*"
  #           Resource  = ["<BUCKET_NAME>", "<BUCKET_NAME>/*"]
  #         },
  #         {
  #           Sid       = "PublicRead"
  #           Effect    = "Allow"
  #           Principal = "*"
  #           Action    = "s3:GetObject"
  #           Resource  = "<BUCKET_NAME>/*"
  #         }
  #       ]
  #     })
  #   }
  # }
  bucket_policies = {}

  # ---------------------------------------------------------------------------
  # Object Lock Configuration (Uncomment if using compliance bucket)
  # ---------------------------------------------------------------------------
  #
  # bucket_lock_configurations = {
  #   compliance_lock = {
  #     bucket_key = "compliance"
  #     rule = {
  #       default_retention = {
  #         mode = "COMPLIANCE"  # Cannot be overridden
  #         years = 7           # 7-year retention
  #       }
  #     }
  #   }
  # }

  # ---------------------------------------------------------------------------
  # Initial Objects
  # ---------------------------------------------------------------------------

  objects = {
    # robots.txt for website
    robots_txt = {
      bucket_key   = "website"
      key          = "robots.txt"
      content      = "User-agent: *\nAllow: /"
      content_type = "text/plain"
      visibility   = "public-read"
    }

    # Health check endpoint
    health_json = {
      bucket_key   = "website"
      key          = "health.json"
      content      = jsonencode({ status = "ok", version = "1.0.0" })
      content_type = "application/json"
      visibility   = "public-read"
    }

    # Placeholder index page
    index_html = {
      bucket_key   = "website"
      key          = "index.html"
      content      = <<-HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>Welcome</title>
          <meta charset="utf-8">
        </head>
        <body>
          <h1>Welcome to ${var.prefix}</h1>
          <p>Environment: ${var.environment}</p>
        </body>
        </html>
      HTML
      content_type = "text/html"
      visibility   = "public-read"
    }
  }
}

# ==============================================================================
# Variables
# ==============================================================================

variable "organization_id" {
  description = "Scaleway Organization ID (UUID format)"
  type        = string
  default     = "f3d8393e-008a-4fb2-a4ff-81b6fe5c01b0"
}

variable "project_name" {
  description = "Scaleway Project name where resources will be created"
  type        = string
  default     = "default"
}

variable "prefix" {
  description = "Prefix for bucket names (must be globally unique across Scaleway)"
  type        = string
  default     = "test-storage"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.prefix))
    error_message = "Prefix must be 3-21 lowercase alphanumeric characters with hyphens."
  }
}

variable "environment" {
  description = "Environment name (development, integration, staging, production, dev, int, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["development", "integration", "staging", "production", "dev", "int", "prod"], var.environment)
    error_message = "Environment must be: development, staging, or production."
  }
}
