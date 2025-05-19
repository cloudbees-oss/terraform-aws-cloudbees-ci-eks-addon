# Common variables
variable "name" {
  description = "Base name for all resources"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "is_primary" {
  description = "Whether this is the primary region"
  type        = bool
}

variable "hosted_zone" {
  description = "Domain name for Route53 zone and CloudBees CI configuration"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "cert_arn" {
  description = "ARN of the ACM certificate for CloudBees CI"
  type        = string
}

variable "trial_license" {
  description = "Whether to use a trial license for CloudBees CI"
  type        = bool
  default     = true
}

variable "replication_role_arn" {
  description = "The ARN of the IAM role for S3 replication"
  type        = string
  default     = null
}

variable "replication_destination_bucket" {
  description = "The ARN of the destination bucket for replication"
  type        = string
  default     = null
}

variable "efs_id" {
  description = "The ID of the EFS file system to use"
  type        = string
}

variable "velero_bucket_id" {
  description = "The ID of the S3 bucket for Velero backups"
  type        = string
}