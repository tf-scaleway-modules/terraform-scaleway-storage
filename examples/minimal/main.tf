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

  # Optional: null keeps the provider's default project and region
  project_id = var.project_id
  region     = "fr-par"

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

variable "project_id" {
  description = "Scaleway Project ID (UUID) where resources are created; null uses the provider default project"
  type        = string
  default     = null
}

variable "prefix" {
  description = "Prefix for bucket names (must be globally unique)"
  type        = string
  default     = "example"
}
