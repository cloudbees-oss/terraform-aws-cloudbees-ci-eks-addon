data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

data "aws_route53_zone" "this" {
  name = var.hosted_zone
}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  name = var.suffix == "" ? "cbci-bp02" : "cbci-bp02-${var.suffix}"

  vpc_cidr = "10.0.0.0/16"
  #It assumes that AZ as named as "a", "b", "c" consecutively.
  azs_count        = 3
  azs              = slice(data.aws_availability_zones.available.names, 0, local.azs_count)
  route53_zone_id  = data.aws_route53_zone.this.id
  route53_zone_arn = data.aws_route53_zone.this.arn

  mng = {
    cbci_apps = {
      taints = {
        key    = "dedicated"
        value  = "cb-apps"
        effect = "NO_SCHEDULE"
      }
      labels = {
        role = "cb-apps"
      }
    }
  }

  #epoch_millis                    = time_static.epoch.unix * 1000

  cbci_s3_prefix             = "cbci"
  fluentbit_s3_location      = "${module.cbci_s3_bucket.s3_bucket_arn}/fluentbit"
  velero_s3_location         = "${module.cbci_s3_bucket.s3_bucket_arn}/velero"
  s3_objects_expiration_days = 90
  s3_onezone_ia              = 30
  s3_glacier                 = 60

  cloudwatch_logs_expiration_days = 7

  aws_backup_schedule           = "cron(0 12 * * ? *)" # Daily at 12:00 UTC
  aws_backup_cold_storage_after = 30                   # Move to cold storage after 30 days
  aws_backup_delete_after       = 365                  # Delete after 365 days

  efs_transition_to_ia                    = "AFTER_30_DAYS"
  efs_transition_to_archive               = "AFTER_90_DAYS"
  efs_transition_to_primary_storage_class = "AFTER_1_ACCESS"

  tags = merge(var.tags, {
    "tf-blueprint"  = local.name
    "tf-repository" = "github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon"
  })

}

# resource "time_static" "epoch" {
#   depends_on = [module.eks_blueprints_addons]
# }

################################################################################
# EKS Cluster
################################################################################

module "eks" {
  source = "terraform-aws-modules/eks/aws"
  #vEKSTFMod#
  version = "20.37.2"

  cluster_name                   = local.name
  cluster_endpoint_public_access = true
  #vK8#
  cluster_version = "1.33"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_cluster_creator_admin_permissions = true

  # Security groups based on the best practices doc https://docs.aws.amazon.com/eks/latest/userguide/sec-group-reqs.html.
  #   So, by default the security groups are restrictive. Users needs to enable rules for specific ports required for App requirement or Add-ons
  #   See the notes below for each rule used in these examples
  node_security_group_additional_rules = {
    # Recommended outbound traffic for Node groups
    egress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      self        = true
    }
    # Extend node-to-node security group rules. Recommended and required for the Add-ons
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

    # Allows Control Plane Nodes to talk to Worker nodes on all ports. Added this to simplify the example and further avoid issues with Add-ons communication with Control plane.
    # This can be restricted further to specific port based on the requirement for each Add-on e.g., metrics-server 4443, spark-operator 8080, karpenter 8443 etc.
    # Change this according to your security requirements if needed
    ingress_cluster_to_node_all_traffic = {
      description                   = "Cluster API to Nodegroup all traffic"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  # https://docs.aws.amazon.com/eks/latest/userguide/choosing-instance-type.html
  # https://docs.aws.amazon.com/eks/latest/APIReference/API_Nodegroup.html
  eks_managed_node_group_defaults = {
    capacity_type = "ON_DEMAND"
    disk_size     = 50
  }
  eks_managed_node_groups = {
    # Note: Openldap requires x86_64 architecture
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
    #For Controllers using EFS or EBS
    cb_apps = {
      node_group_name = "cb-apps"
      instance_types  = ["m7g.2xlarge"] #Graviton
      min_size        = 1
      max_size        = 3
      desired_size    = 1
      taints          = [local.mng["cbci_apps"]["taints"]]
      labels = {
        role = local.mng["cbci_apps"]["labels"].role
      }
      ami_type                   = "BOTTLEROCKET_ARM_64"
      platform                   = "bottlerocket"
      enable_bootstrap_user_data = true
      bootstrap_extra_args       = local.bottlerocket_bootstrap_extra_args
      disk_size                  = 100
    }
    #For controllers using EBS, we guarantee there is at least one node in AZ-a to support gp3 EBS volumes
    #https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md#common-notes-and-gotchas
    cb_apps_a = {
      node_group_name = "cb-apps-a"
      instance_types  = ["m7g.2xlarge"] #Graviton
      min_size        = 1
      max_size        = 3
      desired_size    = 1
      taints          = [local.mng["cbci_apps"]["taints"]]
      labels = {
        role = local.mng["cbci_apps"]["labels"].role
      }
      ami_type                   = "BOTTLEROCKET_ARM_64"
      platform                   = "bottlerocket"
      enable_bootstrap_user_data = true
      bootstrap_extra_args       = local.bottlerocket_bootstrap_extra_args
      disk_size                  = 100
      subnet_ids                 = [module.vpc.private_subnets[0]]
    }
  }

  # https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html
  # https://aws.amazon.com/blogs/containers/understanding-and-cost-optimizing-amazon-eks-control-plane-logs/
  # Saved by default in /aws/eks/${local.name}/cluster
  create_cloudwatch_log_group            = true
  cluster_enabled_log_types              = ["audit", "api", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_group_retention_in_days = local.cloudwatch_logs_expiration_days

  tags = merge(local.tags, {
    "karpenter.sh/discovery" = local.name
  })
}

################################################################################
# Supported Resources
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.12.1"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for i in range(0, local.azs_count) : cidrsubnet(local.vpc_cidr, 4, i)]
  public_subnets  = [for i in range(0, local.azs_count) : cidrsubnet(local.vpc_cidr, 4, local.azs_count + i)]

  enable_nat_gateway = true
  single_nat_gateway = true

  #https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html
  #https://docs.aws.amazon.com/eks/latest/userguide/network-load-balancing.html
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    # Tags subnets for Karpenter auto-discovery
    "karpenter.sh/discovery" = local.name
  }

  tags = local.tags

}
module "efs" {
  source  = "terraform-aws-modules/efs/aws"
  version = "1.6.4"

  creation_token = local.name
  name           = local.name

  mount_targets = {
    for k, v in zipmap(local.azs, module.vpc.private_subnets) : k => { subnet_id = v }
  }
  security_group_description = "${local.name} EFS security group"
  security_group_vpc_id      = module.vpc.vpc_id
  security_group_rules = {
    vpc = {
      # relying on the defaults provdied for EFS/NFS (2049/TCP + ingress)
      description = "NFS ingress from VPC private subnets"
      cidr_blocks = module.vpc.private_subnets_cidr_blocks
    }
  }

  #https://docs.cloudbees.com/docs/cloudbees-ci/latest/eks-install-guide/eks-pre-install-requirements-helm#_storage_requirements
  performance_mode = "generalPurpose"
  throughput_mode  = "elastic"

  # https://docs.aws.amazon.com/efs/latest/ug/lifecycle-management-efs.html
  lifecycle_policy = {
    transition_to_ia                    = local.efs_transition_to_ia
    transition_to_archive               = local.efs_transition_to_archive
    transition_to_primary_storage_class = local.efs_transition_to_primary_storage_class
  }

  #Creating a separate backup plan for EFS to set lifecycle policies
  enable_backup_policy = false

  tags = var.tags
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "5.0.0"

  #Important: Application Services Hostname must be the same as the domain name or subject_alternative_names
  domain_name = var.hosted_zone
  subject_alternative_names = [
    "*.${var.hosted_zone}" # For subdomains example.${var.domain_name}
  ]

  #https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html
  zone_id           = local.route53_zone_id
  validation_method = "DNS"

  tags = local.tags
}

resource "aws_resourcegroups_group" "bp_rg" {
  name = local.name

  resource_query {
    query = <<JSON
{
  "ResourceTypeFilters": [
    "AWS::AllSupported"
  ],
  "TagFilters": [
    {
      "Key": "tf-blueprint",
      "Values": ["${local.name}"]
    }
  ]
}
JSON
  }
}

module "cbci_s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.0.1"

  bucket = local.name

  # Allow deletion of non-empty bucket
  # NOTE: This is enabled for example usage only, you should not enable this for production workloads
  force_destroy = true

  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  acl = "private"

  # S3 bucket-level Public Access Block configuration (by default now AWS has made this default as true for S3 bucket-level block public access)
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"

  #SECO-3109
  object_lock_enabled = false

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

  #https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html
  #https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration
  lifecycle_rule = [
    {
      #Use multiple rules to apply different transitions and expiration based on filters (prefix, tags, etc)
      id      = "general"
      enabled = true

      transition = [
        {
          days          = local.s3_onezone_ia
          storage_class = "ONEZONE_IA"
          }, {
          days          = local.s3_glacier
          storage_class = "GLACIER"
        }
      ]

      expiration = {
        days = local.s3_objects_expiration_days
        #expired_object_delete_marker = true
      }
    }
  ]

  tags = local.tags
}

resource "aws_backup_plan" "efs_backup_plan" {
  name = "efs-backup-plan-${local.name}"

  rule {
    rule_name         = "efs-backup-rule"
    target_vault_name = aws_backup_vault.efs_backup_vault.name

    schedule = local.aws_backup_schedule

    lifecycle {
      cold_storage_after = local.aws_backup_cold_storage_after
      delete_after       = local.aws_backup_delete_after
    }
  }
}

resource "aws_backup_vault" "efs_backup_vault" {
  name = "efs-backup-vault-${local.name}"

  kms_key_arn   = aws_kms_key.backup_key.arn
  force_destroy = true
  tags          = var.tags
}

resource "aws_backup_selection" "efs_backup_selection" {
  name         = "efs-backup-selection"
  iam_role_arn = aws_iam_role.backup_role.arn
  plan_id      = aws_backup_plan.efs_backup_plan.id

  resources = [module.efs.arn]
}

resource "aws_iam_role" "backup_role" {
  name = "efs-backup-role-${local.name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })

}

resource "aws_iam_role_policy_attachment" "backup_role_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.backup_role.name
}

resource "aws_kms_key" "backup_key" {
  description = "KMS key for EFS backups"
  tags        = var.tags
}
