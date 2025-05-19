output "primary_region" {
  description = "Primary AWS region"
  value       = var.primary_region
}

output "primary_cluster_name" {
  description = "EKS cluster name in primary region"
  value       = module.primary_region.cluster_name
}

output "secondary_cluster_name" {
  description = "EKS cluster name in secondary region"
  value       = module.secondary_region.cluster_name
}

output "primary_cluster_endpoint" {
  description = "Endpoint for EKS control plane in primary region"
  value       = module.primary_region.cluster_endpoint
}

output "secondary_cluster_endpoint" {
  description = "Endpoint for EKS control plane in secondary region"
  value       = module.secondary_region.cluster_endpoint
}

output "primary_efs_id" {
  description = "ID of the EFS file system in primary region"
  value       = module.primary_region.efs_id
}

output "secondary_efs_id" {
  description = "ID of the EFS file system in secondary region"
  value       = module.secondary_region.efs_id
}

output "primary_vpc_id" {
  description = "ID of the VPC in primary region"
  value       = module.primary_region.vpc_id
}

output "secondary_vpc_id" {
  description = "ID of the VPC in secondary region"
  value       = module.secondary_region.vpc_id
}
