locals {
  name = "cbci-dr"
  tags = {
    Environment = "dr"
    Terraform   = "true"
  }

  # Common variables for region modules
  region_common = {
    hosted_zone    = var.hosted_zone
    cert_arn       = module.acm.acm_certificate_arn
    trial_license  = var.trial_license
  }
}

# Data source for Route53 zone
data "aws_route53_zone" "selected" {
  name = var.hosted_zone
}

# ACM Certificate
module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "4.3.2"

  domain_name = var.hosted_zone
  zone_id     = data.aws_route53_zone.selected.zone_id

  subject_alternative_names = [
    "*.${var.hosted_zone}"
  ]

  wait_for_validation = true

  tags = local.tags
}

# IAM Role for S3 Replication
data "aws_iam_policy_document" "s3_replication_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "s3_replication" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket"
    ]
    resources = [
      module.region_alpha.velero_bucket_arn,
      module.region_beta.velero_bucket_arn
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging"
    ]
    resources = [
      "${module.region_alpha.velero_bucket_arn}/*",
      "${module.region_beta.velero_bucket_arn}/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags"
    ]
    resources = [
      "${module.region_alpha.velero_bucket_arn}/*",
      "${module.region_beta.velero_bucket_arn}/*"
    ]
  }
}

resource "aws_iam_role" "s3_replication" {
  name               = "${local.name}-s3-replication"
  assume_role_policy = data.aws_iam_policy_document.s3_replication_assume_role.json
  tags               = local.tags
}

resource "aws_iam_role_policy" "s3_replication" {
  name   = "${local.name}-s3-replication"
  role   = aws_iam_role.s3_replication.id
  policy = data.aws_iam_policy_document.s3_replication.json
}

# Alpha Region Module
module "region_alpha" {
  source = "./modules/region"

  name        = local.name
  region      = var.region_alpha
  tags        = local.tags
  hosted_zone = local.region_common.hosted_zone
  cert_arn    = local.region_common.cert_arn
  trial_license = local.region_common.trial_license

  is_primary = var.primary_region == "alpha"

  providers = {
    aws = aws.alpha
  }
}

# Beta Region Module
module "region_beta" {
  source = "./modules/region"

  name        = local.name
  region      = var.region_beta
  tags        = local.tags
  hosted_zone = local.region_common.hosted_zone
  cert_arn    = local.region_common.cert_arn
  trial_license = local.region_common.trial_license

  is_primary = var.primary_region == "beta"

  providers = {
    aws = aws.beta
  }
}

# Configure S3 Replication
resource "aws_s3_bucket_replication_configuration" "primary_to_secondary" {
  provider = var.primary_region == "alpha" ? aws.alpha : aws.beta
  depends_on = [module.region_alpha, module.region_beta]

  bucket = var.primary_region == "alpha" ? module.region_alpha.velero_bucket_id : module.region_beta.velero_bucket_id
  role   = aws_iam_role.s3_replication.arn

  rule {
    id     = "replicate-to-secondary"
    status = "Enabled"

    filter {}

    destination {
      bucket        = var.primary_region == "alpha" ? module.region_beta.velero_bucket_arn : module.region_alpha.velero_bucket_arn
      storage_class = "STANDARD"
    }

    delete_marker_replication {
      status = "Enabled"
    }
  }
}

# Configure EFS Replication
resource "aws_efs_replication_configuration" "primary_to_secondary" {
  provider = var.primary_region == "alpha" ? aws.alpha : aws.beta
  depends_on = [module.region_alpha, module.region_beta]

  source_file_system_id = var.primary_region == "alpha" ? module.region_alpha.efs_id : module.region_beta.efs_id
  destination {
    region = var.primary_region == "alpha" ? var.region_beta : var.region_alpha
    availability_zone_name = var.primary_region == "alpha" ? module.region_beta.azs[0] : module.region_alpha.azs[0]
  }
} 