variable "subscription_id" {
  description = "Azure subscription ID used by the azurerm provider."
  type        = string
}

variable "students" {
  description = "Lowercase student identifier used in Azure resource names, for example nom1-nom2."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.students))
    error_message = "students must contain lowercase letters, digits, and single hyphens only."
  }
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "italynorth"
}

variable "admin_ip_cidr" {
  description = "Administrator's public IPv4 address in CIDR notation; must be a /32."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.admin_ip_cidr)) && endswith(var.admin_ip_cidr, "/32")
    error_message = "admin_ip_cidr must be a valid IPv4 /32 address."
  }
}

variable "ssh_public_key_path" {
  description = "Path to the administrator's SSH public key; ~ is expanded."
  type        = string
}

variable "vm_size" {
  description = "VM size used by app and database tiers."
  type        = string
  default     = "Standard_A1_v2"
}

variable "web_vm_size" {
  description = "VM size used by the public web tier."
  type        = string
  default     = "Standard_A1_v2"
}

variable "db_password" {
  description = "Password for the application-only MySQL user. Use at least 12 letters, digits, or _ . : @ % + -; quotes and $ are not allowed."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9_.:@%+-]{11,}$", var.db_password))
    error_message = "db_password must be at least 12 characters, start with a letter or digit, and use only letters, digits, _ . : @ % + -."
  }
}

variable "repo_url" {
  description = "HTTPS URL of the public Git repository containing the configured app_subdir."
  type        = string

  validation {
    condition     = startswith(var.repo_url, "https://")
    error_message = "repo_url must be an HTTPS URL for a public Git repository."
  }
}

variable "app_subdir" {
  description = "Repository path containing backend/ and frontend/."
  type        = string
  default     = "app"

  validation {
    condition     = can(regex("^[A-Za-z0-9._/-]*$", var.app_subdir)) && !startswith(var.app_subdir, "/") && !strcontains(var.app_subdir, "..")
    error_message = "app_subdir must be a relative repository path without '..'."
  }
}
