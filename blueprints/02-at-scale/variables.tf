############
# Required
############

variable "hosted_zone" {
  description = "Amazon Route 53 hosted zone. CloudBees CI applications are configured to use subdomains in this hosted zone."
  type        = string
}

variable "trial_license" {
  description = "CloudBees CI trial license details for evaluation."
  type        = map(string)
}

variable "dh_reg_secret_auth" {
  description = "Docker Hub registry server authentication details for cbci-sec-reg secret."
  type        = map(string)
  default = {
    username = "foo"
    password = "changeme1234"
    email    = "foo.bar@acme.com"
  }
}

############
# Optional
############

variable "suffix" {
  description = "Unique suffix to assign to all resources. When adding the suffix, changes are required in CloudBees CI for the validation phase."
  default     = ""
  type        = string
  validation {
    condition     = length(var.suffix) <= 10
    error_message = "The suffix can contain 10 characters or less."
  }
}

#Check number of AZ: aws ec2 describe-availability-zones --region var.aws_region
variable "aws_region" {
  description = "AWS region to deploy resources to. It requires a minimum of three availability zones."
  type        = string
  default     = "us-west-2"
}

variable "tags" {
  description = "Tags to apply to resources."
  default     = {}
  type        = map(string)
}

############
# Others. Hidden
############

variable "ci" {
  description = "Running in a CI service versus running locally. False when running locally, true when running in a CI service."
  default     = false
  type        = bool
}
