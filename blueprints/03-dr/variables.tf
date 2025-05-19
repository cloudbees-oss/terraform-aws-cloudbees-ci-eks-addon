variable "region_alpha" {
  description = "AWS region for alpha deployment"
  type        = string
}

variable "region_beta" {
  description = "AWS region for beta deployment"
  type        = string
}

variable "primary_region" {
  description = "Which region is primary (alpha or beta)"
  type        = string
  validation {
    condition     = contains(["alpha", "beta"], var.primary_region)
    error_message = "Primary region must be either 'alpha' or 'beta'."
  }
}

variable "hosted_zone" {
  description = "Domain name for Route53 zone and CloudBees CI configuration"
  type        = string
}

variable "suffix" {
  description = "Suffix to append to all resource names"
  type        = string
  default     = ""
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "trial_license" {
  description = "Whether to use a trial license for CloudBees CI"
  type        = bool
  default     = true
} 