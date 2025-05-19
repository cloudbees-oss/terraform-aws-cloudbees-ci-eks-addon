# CloudBees CI Disaster Recovery Blueprint

This blueprint deploys CloudBees CI in a disaster recovery (DR) setup across two AWS regions using EKS. The setup includes:

- Two EKS clusters (one in each region)
- EFS file systems with replication between regions
- CloudBees CI deployment in the primary region (configurable as alpha or beta)
- Automatic DNS failover using Route53
- ACM certificate for secure HTTPS access

## Architecture

The blueprint creates the following resources in two AWS regions (alpha and beta). The primary region can be configured as either alpha or beta:

### High-Level Architecture
![DR Architecture](img/dr-architecture.drawio.svg)

### Kubernetes Components
![DR Kubernetes](img/dr-k8s.drawio.svg)

### Primary Region (Alpha or Beta)
- VPC with public and private subnets
- EKS cluster with managed node groups
- EFS file system
- CloudBees CI deployment
- EKS addons:
  - CoreDNS
  - VPC CNI
  - kube-proxy
  - External DNS
  - AWS Load Balancer Controller
  - EFS CSI Driver

### Secondary Region (Alpha or Beta)
- VPC with public and private subnets
- EKS cluster with managed node groups
- EFS file system (replicated from primary)
- EKS addons:
  - CoreDNS
  - VPC CNI
  - kube-proxy
  - EFS CSI Driver

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- kubectl
- helm

## Usage

1. Create a `.auto.tfvars` file with your configuration:

```hcl
region_alpha = "us-west-2"  # Alpha region
region_beta  = "us-east-1"  # Beta region
hosted_zone  = "example.com"

trial_license = true  # Set to false if using a production license
```

2. Set the primary region using the environment variable:

```bash
export TF_VAR_primary_region="alpha"  # or "beta"
```

3. Initialize Terraform:

```bash
terraform init
```

4. Review the plan:

```bash
terraform plan
```

5. Apply the configuration:

```bash
terraform apply
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| region_alpha | AWS region for alpha deployment | `string` | n/a | yes |
| region_beta | AWS region for beta deployment | `string` | n/a | yes |
| primary_region | Which region is primary (alpha or beta) | `string` | n/a | yes |
| hosted_zone | Domain name for Route53 zone and CloudBees CI | `string` | n/a | yes |
| trial_license | Whether to use a trial license for CloudBees CI | `bool` | `true` | no |
| tags | A map of tags to add to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| alpha_cluster_name | Name of the EKS cluster in alpha region |
| alpha_cluster_endpoint | Endpoint for the EKS cluster in alpha region |
| alpha_efs_id | ID of the EFS file system in alpha region |
| alpha_vpc_id | ID of the VPC in alpha region |
| beta_cluster_name | Name of the EKS cluster in beta region |
| beta_cluster_endpoint | Endpoint for the EKS cluster in beta region |
| beta_efs_id | ID of the EFS file system in beta region |
| beta_vpc_id | ID of the VPC in beta region |

## Disaster Recovery

In case of a disaster in the primary region:

1. Update the primary region by changing the environment variable:
   ```bash
   export TF_VAR_primary_region="beta"  # Switch to beta as primary
   ```
2. The EFS replication ensures data is available in the secondary region
3. Apply the changes to update the configuration:
   ```bash
   terraform apply
   ```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

## License

This blueprint is licensed under the Apache License 2.0. 