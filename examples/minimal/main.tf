# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                         MINIMAL EXAMPLE                                       ║
# ║                                                                                ║
# ║  Demonstrates the simplest usage of the Scaleway Object Storage module.       ║
# ║  Creates a single private bucket with default settings.                       ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# Module Configuration
# ==============================================================================

module "storage" {
  source = "../../"

  # Required: Scaleway organization and project
  organization_id = var.organization_id
  project_name    = var.project_name

  # Optional: Override default region (fr-par)
  region = "fr-par"

  # Create a single private bucket
  buckets = {
    data = {
      name = "${var.prefix}-data-bucket"
      # All other options use defaults:
      # acl           = "private"
      # force_destroy = false
      # versioning    = false
    }
  }
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
  description = "Prefix for bucket names (must be globally unique)"
  type        = string
  default     = "example"
}
