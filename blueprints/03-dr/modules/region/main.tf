locals {
  region_name = "${var.name}-${var.region}"
  vpc_cidr    = "10.0.0.0/16"
  azs         = slice(data.aws_availability_zones.available.names, 0, 3)
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.12.1"

  name = local.region_name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "karpenter.sh/discovery"         = local.region_name
  }

  tags = var.tags
}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.23.0"

  cluster_name                   = local.region_name
  cluster_endpoint_public_access = true
  cluster_version               = "1.32"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_cluster_creator_admin_permissions = true

  node_security_group_additional_rules = {
    egress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      self        = true
    }
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_ssh_all = {
      description      = "Egress all ssh to internet for github"
      protocol         = "tcp"
      from_port        = 22
      to_port          = 22
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
    ingress_cluster_to_node_all_traffic = {
      description                   = "Cluster API to Nodegroup all traffic"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  eks_managed_node_group_defaults = {
    capacity_type = "ON_DEMAND"
    disk_size     = 50
  }

  eks_managed_node_groups = {
    shared_apps = {
      node_group_name = "shared"
      instance_types  = ["m7a.2xlarge"]
      ami_type        = "BOTTLEROCKET_x86_64"
      platform        = "bottlerocket"
      min_size        = 1
      max_size        = 3
      desired_size    = 1
      labels = {
        role = "shared"
      }
    }
  }

  tags = var.tags
}

# CloudBees CI Addons
module "eks_blueprints_addons_cbci" {
  count = var.is_primary ? 1 : 0

  source  = "cloudbees/cloudbees-ci-eks-addon/aws"
  version = ">= 3.21450.0"

  depends_on = [module.eks_blueprints_addons]

  hosted_zone   = var.hosted_zone
  cert_arn      = var.cert_arn
  trial_license = var.trial_license
}

# EKS Blueprints Addons
module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.20.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  oidc_provider_arn = module.eks.oidc_provider_arn
  cluster_version   = module.eks.cluster_version

  eks_addons = {
    coredns    = {}
    vpc-cni    = {}
    kube-proxy = {}
  }

  enable_external_dns = var.is_primary
  external_dns = var.is_primary ? {
    values = [templatefile("k8s/extdns-values.yml", {
      zoneDNS = var.hosted_zone
    })]
  } : {}
  external_dns_route53_zone_arns      = var.is_primary ? [data.aws_route53_zone.selected.arn] : []
  enable_aws_load_balancer_controller = true

  enable_aws_efs_csi_driver = true
  aws_efs_csi_driver = {
    values = [templatefile("k8s/aws-efs-csi-driver-values.yml", {
      file_system_id = var.efs_id
    })]
  }

  # Enable Velero addon
  enable_velero = true
  velero = {
    values = [templatefile("k8s/velero-values.yml", {
      bucket_name = var.velero_bucket_id
      region      = var.region
      aws_iam_role_arn = aws_iam_role.velero.arn
    })]
  }

  tags = var.tags
}

# Storage Class for EFS
resource "kubernetes_storage_class_v1" "efs" {
  metadata {
    name = "efs"
  }
  depends_on = [module.eks]

  storage_provisioner = "efs.csi.aws.com"
  reclaim_policy      = "Delete"
  parameters = {
    # Dynamic provisioning
    provisioningMode = "efs-ap"
    fileSystemId     = module.efs.id
    directoryPerms   = "700"
    uid = "1000"
    gid = "1000"
    #Required for DR
    subPathPattern = "$${.PVC.namespace}/$${.PVC.name}"
    ensureUniqueDirectory = "false"
    reuseAccessPoint = "true"
  }

  mount_options = [
    "iam"
  ]
}

# EFS
module "efs" {
  source  = "terraform-aws-modules/efs/aws"
  version = "1.6.4"

  creation_token = local.region_name
  name           = local.region_name

  mount_targets = {
    for k, v in zipmap(local.azs, module.vpc.private_subnets) : k => { subnet_id = v }
  }

  security_group_description = "${local.region_name} EFS security group"
  security_group_vpc_id      = module.vpc.vpc_id
  security_group_rules = {
    vpc = {
      description = "NFS ingress from VPC private subnets"
      cidr_blocks = module.vpc.private_subnets_cidr_blocks
    }
  }

  performance_mode = "generalPurpose"
  throughput_mode  = "elastic"

  tags = var.tags
}

# S3 Bucket for Velero
module "velero_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.0.1"

  bucket = "${local.region_name}-velero"

  # Allow deletion of non-empty bucket
  force_destroy = true

  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  acl = "private"

  # S3 bucket-level Public Access Block configuration
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"

  versioning = {
    status     = true
    mfa_delete = false
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule = [
    {
      id      = "general"
      enabled = true

      transition = [
        {
          days          = 30
          storage_class = "ONEZONE_IA"
        },
        {
          days          = 60
          storage_class = "GLACIER"
        }
      ]

      expiration = {
        days = 90
      }
    }
  ]

  tags = var.tags
} 