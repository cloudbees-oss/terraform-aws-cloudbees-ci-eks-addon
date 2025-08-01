# Copyright (c) CloudBees, Inc.

locals {
  #vCBCI_Helm#
  cbci_version           = "3.28667.0+d3da5d8d9ee8"
  cbci_ns                = "cbci"
  cbci_sec_casc_name     = "cbci-sec-casc"
  cbci_sec_registry_name = "cbci-sec-reg"
  create_secret_casc     = alltrue([var.create_casc_secrets, length(var.casc_secrets_file) > 0])
  create_secret_reg      = alltrue([var.create_reg_secret, length(var.reg_secret_ns) > 0, length(var.reg_secret_auth) > 0])
  #This section needs to be included in controllers to make use of the CBCI Casc Secrets
  oc_secrets_mount = [
    <<-EOT
      OperationsCenter:
        ContainerEnv:
          - name: SECRETS
            value: /var/run/secrets/cbci
        ExtraVolumes:
          - name: cbci-secrets
            secret:
              secretName: ${local.cbci_sec_casc_name}
        ExtraVolumeMounts:
          - name: cbci-secrets
            mountPath: /var/run/secrets/cbci
            readOnly: true
      EOT
  ]
  cbci_template_values = {
    hosted_zone  = var.hosted_zone
    cert_arn     = var.cert_arn
    LicFirstName = var.trial_license["first_name"]
    LicLastName  = "${var.trial_license["last_name"]} [EKS_TF_ADDON]"
    LicEmail     = var.trial_license["email"]
    LicCompany   = var.trial_license["company"]
  }

  create_prometheus_target = alltrue([var.create_prometheus_target, length(var.prometheus_target_ns) > 0])
  prometheus_sm_labels = {
    "cloudbees.prometheus" = "true"
  }
  prometheus_sm_labels_yaml = yamlencode(local.prometheus_sm_labels)

  create_pi_s3  = alltrue([var.create_pi_s3, length(var.pi_s3_bucket_cbci_prefix) > 0])
  create_pi_ecr = alltrue([var.create_pi_ecr, length(var.pi_ecr_cbci_agents_ns) > 0])
}

################################################################################
# Namespace
################################################################################

# It is required to be separted to purge correctly the cloudbees-ci release
resource "kubernetes_namespace" "cbci" {
  count = try(var.helm_config.create_namespace, true) ? 1 : 0
  metadata {
    name = try(var.helm_config.namespace, local.cbci_ns)
  }
}

resource "time_sleep" "wait_30_seconds" {
  depends_on = [kubernetes_namespace.cbci]

  destroy_duration = "30s"
}

################################################################################
# Secrets
################################################################################

# Kubernetes Secrets to be passed to Casc
# https://github.com/jenkinsci/configuration-as-code-plugin/blob/master/docs/features/secrets.adoc#kubernetes-secrets
resource "kubernetes_secret" "cbci_sec_casc" {
  count = local.create_secret_casc ? 1 : 0

  metadata {
    name      = local.cbci_sec_casc_name
    namespace = kubernetes_namespace.cbci[0].metadata[0].name
  }

  type = "Opaque"

  data = yamldecode(var.casc_secrets_file)
}

# Kubernetes Secrets to authenticate with DockerHub
# https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/using-kaniko#_create_a_new_kubernetes_secret
resource "kubernetes_secret" "cbci_sec_reg" {
  count = local.create_secret_reg ? 1 : 0
  # Agent namespace needs to be created before creating this secret
  depends_on = [helm_release.cloudbees_ci]
  metadata {
    name      = local.cbci_sec_registry_name
    namespace = var.reg_secret_ns
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        (var.reg_secret_auth["server"]) = {
          "username" = var.reg_secret_auth["username"]
          "password" = var.reg_secret_auth["password"]
          "email"    = var.reg_secret_auth["email"]
          "auth"     = base64encode("${var.reg_secret_auth["username"]}:${var.reg_secret_auth["password"]}")
        }
      }
    })
  }
}

################################################################################
# Prometheus ServiceMonitor
################################################################################

resource "kubectl_manifest" "service_monitor_cb_controllers" {
  count = local.create_prometheus_target ? 1 : 0

  yaml_body = <<YAML
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: servicemonitor-cbci
  namespace: ${var.prometheus_target_ns}
  labels:
    release: kube-prometheus-stack
    app.kubernetes.io/part-of: kube-prometheus-stack
spec:
  namespaceSelector:
    matchNames:
      - ${helm_release.cloudbees_ci.namespace}
  selector:
    matchLabels:
      ${local.prometheus_sm_labels_yaml}
  endpoints:
    - port: http
      interval: 30s
      path: /prometheus/
YAML
}

resource "kubernetes_labels" "oc_sm_label" {
  count = local.create_prometheus_target ? 1 : 0

  api_version = "v1"
  kind        = "Service"
  # This is true because the resources was already created by the helm_release
  force = "true"

  metadata {
    name      = "cjoc"
    namespace = helm_release.cloudbees_ci.namespace
  }

  labels = local.prometheus_sm_labels
}

################################################################################
# Pod Identity
################################################################################

data "aws_iam_policy_document" "assume_role_eks_pod" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

# S3

resource "aws_iam_role" "role_s3" {
  count = local.create_pi_s3 ? 1 : 0

  name               = "${var.pi_eks_cluster_name}_role_s3"
  assume_role_policy = data.aws_iam_policy_document.assume_role_eks_pod.json
}

resource "aws_iam_role_policy" "s3_policy" {
  count = local.create_pi_s3 ? 1 : 0

  name = "${var.pi_eks_cluster_name}_policy_s3"
  role = aws_iam_role.role_s3[0].id
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      #https://docs.cloudbees.com/docs/cloudbees-ci/latest/pipelines/cloudbees-cache-step#_s3_configuration
      "Statement" : [
        {
          "Sid" : "cbciS3BucketputGetDelete",
          "Effect" : "Allow",
          "Action" : [
            "s3:PutObject",
            "s3:GetObject",
            "s3:DeleteObject"
          ],
          "Resource" : "${var.pi_s3_bucket_arn}/${var.pi_s3_bucket_cbci_prefix}/*"
        },
        {
          "Sid" : "cbciS3BucketList",
          "Effect" : "Allow",
          "Action" : "s3:ListBucket",
          "Resource" : var.pi_s3_bucket_arn,
          "Condition" : {
            "StringLike" : {
              "s3:prefix" : "${var.pi_s3_bucket_cbci_prefix}/*"
            }
          }
        }
      ]
    }
  )
}

resource "aws_eks_pod_identity_association" "services_s3" {
  for_each = local.create_pi_s3 ? toset(var.pi_s3_sa_controllers) : []

  cluster_name    = var.pi_eks_cluster_name
  namespace       = helm_release.cloudbees_ci.namespace
  service_account = each.key
  role_arn        = aws_iam_role.role_s3[0].arn
}

# ECR

resource "aws_iam_role" "role_ecr" {
  count = local.create_pi_ecr ? 1 : 0

  name               = "${var.pi_eks_cluster_name}_role_ecr"
  assume_role_policy = data.aws_iam_policy_document.assume_role_eks_pod.json
}

resource "aws_iam_role_policy" "ecr_policy" {
  count = local.create_pi_ecr ? 1 : 0

  name = "${var.pi_eks_cluster_name}_policy_ecr"
  role = aws_iam_role.role_ecr[0].id
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "ecrKaniko",
          "Effect" : "Allow",
          "Action" : [
            "ecr:GetDownloadUrlForLayer",
            "ecr:GetAuthorizationToken",
            "ecr:InitiateLayerUpload",
            "ecr:UploadLayerPart",
            "ecr:CompleteLayerUpload",
            "ecr:PutImage",
            "ecr:BatchGetImage",
            "ecr:BatchCheckLayerAvailability"
          ],
          "Resource" : "*"
        }
      ]
    }
  )
}

resource "aws_eks_pod_identity_association" "agent_ecr" {
  count      = local.create_pi_ecr ? 1 : 0
  depends_on = [helm_release.cloudbees_ci]

  cluster_name    = var.pi_eks_cluster_name
  namespace       = var.pi_ecr_cbci_agents_ns
  service_account = "jenkins-agents"
  role_arn        = aws_iam_role.role_ecr[0].arn
}

################################################################################
# Helm Release
################################################################################

resource "helm_release" "cloudbees_ci" {
  name                       = try(var.helm_config.name, "cloudbees-ci")
  namespace                  = try(var.helm_config.namespace, kubernetes_namespace.cbci[0].metadata[0].name)
  create_namespace           = false
  description                = try(var.helm_config.description, null)
  chart                      = "cloudbees-core"
  version                    = try(var.helm_config.version, local.cbci_version)
  repository                 = try(var.helm_config.repository, "https://public-charts.artifacts.cloudbees.com/repository/public/")
  values                     = local.create_secret_casc ? concat(var.helm_config.values, local.oc_secrets_mount, [templatefile("${path.module}/values.yml", local.cbci_template_values)]) : concat(var.helm_config.values, [templatefile("${path.module}/values.yml", local.cbci_template_values)])
  timeout                    = try(var.helm_config.timeout, 1200)
  repository_key_file        = try(var.helm_config.repository_key_file, null)
  repository_cert_file       = try(var.helm_config.repository_cert_file, null)
  repository_ca_file         = try(var.helm_config.repository_ca_file, null)
  repository_username        = try(var.helm_config.repository_username, null)
  repository_password        = try(var.helm_config.repository_password, null)
  devel                      = try(var.helm_config.devel, null)
  verify                     = try(var.helm_config.verify, null)
  keyring                    = try(var.helm_config.keyring, null)
  disable_webhooks           = try(var.helm_config.disable_webhooks, null)
  reuse_values               = try(var.helm_config.reuse_values, null)
  reset_values               = try(var.helm_config.reset_values, null)
  force_update               = try(var.helm_config.force_update, null)
  recreate_pods              = try(var.helm_config.recreate_pods, null)
  cleanup_on_fail            = try(var.helm_config.cleanup_on_fail, null)
  max_history                = try(var.helm_config.max_history, null)
  atomic                     = try(var.helm_config.atomic, null)
  skip_crds                  = try(var.helm_config.skip_crds, null)
  render_subchart_notes      = try(var.helm_config.render_subchart_notes, null)
  disable_openapi_validation = try(var.helm_config.disable_openapi_validation, null)
  wait                       = try(var.helm_config.wait, true)
  wait_for_jobs              = try(var.helm_config.wait_for_jobs, null)
  dependency_update          = try(var.helm_config.dependency_update, null)
  replace                    = try(var.helm_config.replace, null)
  lint                       = try(var.helm_config.lint, null)

  dynamic "postrender" {
    for_each = can(var.helm_config.postrender_binary_path) ? [1] : []

    content {
      binary_path = var.helm_config.postrender_binary_path
    }
  }

  dynamic "set" {
    for_each = try(var.helm_config.set, [])

    content {
      name  = set.value.name
      value = set.value.value
      type  = try(set.value.type, null)
    }
  }

  dynamic "set_sensitive" {
    for_each = try(var.helm_config.set_sensitive, {})

    content {
      name  = set_sensitive.value.name
      value = set_sensitive.value.value
      type  = try(set_sensitive.value.type, null)
    }
  }

  depends_on = [time_sleep.wait_30_seconds]
}
