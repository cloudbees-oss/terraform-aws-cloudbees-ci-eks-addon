# VPC outputs
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnets
}

output "private_subnets_cidr_blocks" {
  description = "List of private subnet CIDR blocks"
  value       = module.vpc.private_subnets_cidr_blocks
}

# EFS outputs
output "efs_id" {
  description = "The ID of the EFS file system"
  value       = module.efs.id
}

output "efs_arn" {
  description = "The ARN of the EFS file system"
  value       = module.efs.arn
}

# S3 outputs
output "velero_bucket_id" {
  description = "The ID of the Velero S3 bucket"
  value       = module.velero_s3_bucket.s3_bucket_id
}

output "velero_bucket_arn" {
  description = "The ARN of the Velero S3 bucket"
  value       = module.velero_s3_bucket.s3_bucket_arn
}

# EKS outputs
output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "The endpoint for the EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "The certificate authority data for the EKS cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC provider"
  value       = module.eks.oidc_provider_arn
}

# AZs output for replication
output "azs" {
  description = "List of availability zones"
  value       = local.azs
} 