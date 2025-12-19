# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              MODULE OUTPUTS                                   ║
# ║                                                                                ║
# ║  Outputs for integrating with other modules and external systems.             ║
# ║  All sensitive values are marked appropriately.                               ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# Project & Region Outputs
# ------------------------------------------------------------------------------
# Base information about where resources are deployed.
# ==============================================================================

output "project_id" {
  description = "Scaleway Project ID where all resources are created."
  value       = data.scaleway_account_project.project.id
}

output "region" {
  description = "Region where all buckets are deployed."
  value       = var.region
}

# ==============================================================================
# S3 API Endpoints
# ------------------------------------------------------------------------------
# Connection details for S3-compatible clients (AWS SDK, CLI, etc.).
# ==============================================================================

output "s3_endpoint" {
  description = <<-EOT
    S3 API endpoint for the configured region.

    Use this endpoint to configure S3-compatible clients:
    - AWS CLI: aws configure set s3.endpoint_url <endpoint>
    - AWS SDK: endpoint_url parameter
    - s3cmd, rclone, etc.
  EOT
  value       = local.s3_endpoint
}

# ==============================================================================
# Bucket Outputs
# ------------------------------------------------------------------------------
# Complete information about all created buckets.
# ==============================================================================

output "buckets" {
  description = <<-EOT
    Map of all created buckets with their complete details.

    Each bucket includes:
    - id: Scaleway resource ID
    - name: Bucket name
    - endpoint: S3 bucket endpoint URL
    - api_endpoint: S3 API endpoint
    - versioning_enabled: Whether versioning is active
    - object_lock_enabled: Whether WORM is enabled
    - tags: Applied tags
  EOT
  value = {
    for k, v in scaleway_object_bucket.this : k => {
      id                  = v.id
      name                = v.name
      endpoint            = "https://${v.name}.s3.${var.region}.scw.cloud"
      api_endpoint        = local.s3_endpoint
      versioning_enabled  = v.versioning[0].enabled
      object_lock_enabled = v.object_lock_enabled
      tags                = v.tags
    }
  }
}

output "bucket_names" {
  description = "List of all bucket names created by this module."
  value       = [for v in scaleway_object_bucket.this : v.name]
}

output "bucket_ids" {
  description = "Map of bucket keys to their Scaleway resource IDs."
  value       = { for k, v in scaleway_object_bucket.this : k => v.id }
}

output "bucket_endpoints" {
  description = <<-EOT
    Map of bucket keys to their S3 endpoints.

    Format: https://<bucket-name>.s3.<region>.scw.cloud
    Use these URLs for direct bucket access via S3 protocol.
  EOT
  value = {
    for k, v in scaleway_object_bucket.this : k => "https://${v.name}.s3.${var.region}.scw.cloud"
  }
}

output "bucket_arns" {
  description = <<-EOT
    Map of bucket keys to their ARN-style identifiers.

    Format: arn:scw:s3:::<bucket-name>
    Use in bucket policies and IAM configurations.
  EOT
  value = {
    for k, v in scaleway_object_bucket.this : k => "arn:scw:s3:::${v.name}"
  }
}

# ==============================================================================
# Website Hosting Outputs
# ------------------------------------------------------------------------------
# URLs and configuration for buckets with static website hosting enabled.
# ==============================================================================

output "website_endpoints" {
  description = <<-EOT
    Map of bucket keys to their static website endpoints.

    Only populated for buckets with website configuration.
    Format: https://<bucket-name>.s3-website.<region>.scw.cloud
  EOT
  value = {
    for k, v in scaleway_object_bucket_website_configuration.this : k => {
      endpoint       = "https://${v.bucket}.s3-website.${var.region}.scw.cloud"
      index_document = v.index_document[0].suffix
      error_document = try(v.error_document[0].key, null)
    }
  }
}

output "website_urls" {
  description = "Simple map of bucket keys to website URLs (for buckets with website config)."
  value = {
    for k, v in scaleway_object_bucket_website_configuration.this : k =>
    "https://${v.bucket}.s3-website.${var.region}.scw.cloud"
  }
}

# ==============================================================================
# Object Lock Outputs
# ------------------------------------------------------------------------------
# WORM compliance configuration details.
# ==============================================================================

output "lock_configurations" {
  description = <<-EOT
    Map of bucket lock configurations for WORM compliance.

    Includes retention mode and period for each configured bucket.
  EOT
  value = {
    for k, v in scaleway_object_bucket_lock_configuration.this : k => {
      bucket = v.bucket
      mode   = v.rule[0].default_retention[0].mode
      days   = v.rule[0].default_retention[0].days
      years  = v.rule[0].default_retention[0].years
    }
  }
}

# ==============================================================================
# Objects Outputs
# ------------------------------------------------------------------------------
# Information about uploaded objects.
# ==============================================================================

output "objects" {
  description = <<-EOT
    Map of all uploaded objects with their details.

    Includes object location, content type, and visibility.
  EOT
  value = {
    for k, v in scaleway_object.this : k => {
      id           = v.id
      bucket       = v.bucket
      key          = v.key
      url          = "https://${v.bucket}.s3.${var.region}.scw.cloud/${v.key}"
      content_type = v.content_type
      visibility   = v.visibility
    }
  }
}

output "object_urls" {
  description = "Map of object keys to their direct URLs."
  value = {
    for k, v in scaleway_object.this : k =>
    "https://${v.bucket}.s3.${var.region}.scw.cloud/${v.key}"
  }
}

# ==============================================================================
# Connection Configuration Outputs
# ------------------------------------------------------------------------------
# Ready-to-use configuration snippets for common tools.
# ==============================================================================

output "aws_cli_config" {
  description = <<-EOT
    AWS CLI configuration commands for connecting to Scaleway Object Storage.

    Run these commands to configure the AWS CLI:
    aws configure set s3.endpoint_url <s3_endpoint>
    aws configure set default.region <region>
  EOT
  value = {
    endpoint = local.s3_endpoint
    region   = var.region
    commands = [
      "aws configure set s3.endpoint_url ${local.s3_endpoint}",
      "aws configure set default.region ${var.region}"
    ]
  }
}

output "environment_variables" {
  description = <<-EOT
    Environment variables for S3-compatible tools.

    Export these in your shell or CI/CD pipeline:
    export AWS_ENDPOINT_URL_S3=<endpoint>
    export AWS_REGION=<region>
  EOT
  value = {
    AWS_ENDPOINT_URL_S3 = local.s3_endpoint
    AWS_REGION          = var.region
  }
}
