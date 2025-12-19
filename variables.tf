# ==============================================================================
# Organization & Project
# ==============================================================================

variable "organization_id" {
  description = "Scaleway Organization ID."
  type        = string
}

variable "project_name" {
  description = "Scaleway Project name where all resources will be created."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,61}[a-z0-9]$", var.project_name))
    error_message = "Project name must be lowercase alphanumeric with hyphens, start with a letter, and be 2-63 characters."
  }
}

variable "name" {
  description = "Name for resource naming and tagging."
  type        = string
}

# ==============================================================================
# Global Configuration
# ==============================================================================

variable "zone" {
  description = "Scaleway zone (e.g., fr-par-1, nl-ams-1)."
  type        = string
  default     = "fr-par-1"
}

variable "tags" {
  description = "Global tags applied to all resources."
  type        = list(string)
  default     = []
}
