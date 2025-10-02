# CloudBees CI add-on for Amazon EKS blueprints

<p align="center">
  <a href="https://www.cloudbees.com/capabilities/continuous-integration">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://images.ctfassets.net/vtn4rfaw6n2j/ieyxgJANPjaYhdkOXM7Ky/c65ade5254cca895cc99bb561df2dd91/Symbol-White.svg?fm=webp&q=85" height="120px">
  <source media="(prefers-color-scheme: light)" srcset="https://images.ctfassets.net/vtn4rfaw6n2j/6A6SnrhpUInrzTDmB3eHSU/e0f759f7f0cbb396af21b220c8259b89/Symbol-Black.svg?fm=webp&q=85" height="120px">
  <img alt="CloudBees CI add-on for Amazon EKS blueprints" src="https://images.ctfassets.net/vtn4rfaw6n2j/6A6SnrhpUInrzTDmB3eHSU/e0f759f7f0cbb396af21b220c8259b89/Symbol-Black.svg?fm=webp&q=85" height="120px">
</picture></a></p>

<p align="center">Deploy CloudBees CI to Amazon Web Services (AWS) Elastic Kubernetes Service (EKS) clusters</p>

---

[![GitHub Latest Release)](https://img.shields.io/github/v/release/cloudbees/terraform-aws-cloudbees-ci-eks-addon?logo=github)](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/releases)
[![GitHub Issues](https://img.shields.io/github/issues/cloudbees/terraform-aws-cloudbees-ci-eks-addon?logo=github)](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/issues)
[![Code Quality: Terraform](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/actions/workflows/terraform.yml/badge.svg?event=pull_request)](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/actions/workflows/terraform.yml)
[![Code Quality: Super-Linter](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/actions/workflows/superlinter.yml/badge.svg?event=pull_request)](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/actions/workflows/superlinter.yml)
[![Documentation: MD Links Checker](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/actions/workflows/md-link-checker.yml/badge.svg?event=pull_request)](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/actions/workflows/md-link-checker.yml)
[![Documentation: terraform-docs](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/actions/workflows/terraform-docs.yml/badge.svg?event=pull_request)](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/actions/workflows/terraform-docs.yml)
[![gitleaks badge](https://img.shields.io/badge/protected%20by-gitleaks-blue)](https://github.com/zricethezav/gitleaks#pre-commit)
[![gitsecrets](https://img.shields.io/badge/protected%20by-gitsecrets-blue)](https://github.com/awslabs/git-secrets)

## Motivation

The CloudBees CI [AWS partner add-on](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/aws-partner-addons/) streamlines the adoption and experimentation of CloudBees CI enterprise features by:

- Encapsulating the deployment of [CloudBees CI on modern platforms in AWS EKS](https://docs.cloudbees.com/docs/cloudbees-ci/latest/eks-install-guide/installing-eks-using-helm#_configuring_your_environment) and additional Kubernetes resources into a Terraform module.
- Providing a series of opinionated [blueprints](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/tree/main/blueprints) that implement the CloudBees CI add-on module for use with [Amazon EKS blueprints for Terraform](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/), which are aligned with the [EKS Best Practices Guides](https://aws.github.io/aws-eks-best-practices/).

## Usage

Implementation examples are included in the [blueprints](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/tree/main/blueprints) folder, however, this is the simplest example of usage:

```terraform
module "eks_blueprints_addon_cbci" {
  source  = "cloudbees/cloudbees-ci-eks-addon/aws"
  version = ">= 3.22670.0"

  hosted_zone    = "example.domain.com"
  cert_arn     = "arn:aws:acm:us-east-1:0000000:certificate/0000000-aaaa-bbb-ccc-thisIsAnExample"
  trial_license = {
    first_name  = "Foo"
    last_name  = "Bar"
    email = "foo.bar@acme.com"
    company = "Acme Inc."
  }

}
```

By default, it uses a minimum required configuration described in the Helm chart [values.yaml](values.yml) file. If you need to override any default settings with the chart, you can do so by passing the `helm_config` variable.

## Prerequisites

### Tools

The blueprint `deploy` and `destroy` phases use the same requirements provided in the [AWS EKS Blueprints for Terraform - Prerequisites](https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#prerequisites). However, the blueprint `validate` phase may require additional tooling, such as `jq` and `velero`.

> [!NOTE]
> There is a companion [Dockerfile](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/tree/main/.docker) to run the blueprints in a containerized development environment, ensuring all dependencies are met. It can be built locally using the [Makefile](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/blob/main/blueprints/Makefile) target `make bpAgent-dRun`.

### AWS authentication

Before getting started, you must export your required [AWS environment variables](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html) to your CLI (for example, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_PROFILE`).

### Existing AWS hosted zone

These blueprints rely on an existing hosted zone in AWS Route 53. If you do not have a hosted zone, you can create one by following the [AWS Route 53 documentation](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zones-working-with.html).

## Data Storage Options

The two main components of CloudBees CI - the operations center and managed controllers - use a file system to persist data. By default, data is stored in the [$JENKINS_HOME](https://docs.cloudbees.com/docs/cloudbees-ci/latest/backup-restore/jenkins-home) folder, but can be configured to be stored in Amazon Elastic Block Store (Amazon EBS) or Amazon Elastic File System (Amazon EFS):

- Amazon EBS volumes are scoped to a particular availability zone to offer high-speed, low-latency access to the Amazon Elastic Compute Cloud (Amazon EC2) instances they are connected to. If an availability zone fails, an Amazon EBS volume becomes inaccessible due to file corruption, or there is a service outage, the data on these volumes becomes inaccessible. The operations center and managed controller pods require this persistent data and have no mechanism to replicate the data, so CloudBees recommends frequent backups for Amazon EBS.
- Amazon EFS file systems are scoped to an AWS region and can be accessed from any availability zone in the region that the file system was created in. Using Amazon EFS as a storage class for the operations center and managed controllers allows pods to be rescheduled successfully onto healthy nodes in the event of an availability zone outage. Amazon EFS is more expensive than Amazon EBS, but provides greater fault tolerance.

> [!IMPORTANT]
> CloudBees CI High Availability (HA) (active-active) requires Amazon EFS. For more information, refer to [CloudBees CI EKS storage requirements](https://docs.cloudbees.com/docs/cloudbees-ci/latest/eks-install-guide/eks-pre-install-requirements-helm#_storage_requirements).

> [!NOTE]
> - For more information on pricing and cost analysis, refer to [Amazon EBS pricing](https://aws.amazon.com/ebs/pricing/), [Amazon EFS pricing](https://aws.amazon.com/efs/pricing/), and [CloudBees CI with HA Mode Enabled: Sample cost analysis on AWS](https://www.cloudbees.com/blog/cloudbees-ci-with-ha-mode-enabled-sample-cost-analysis-on-aws).
> - For more information on performance, refer to [Amazon EBS performance](https://docs.aws.amazon.com/ebs/latest/userguide/ebs-performance.html), [Amazon EFS performance](https://docs.aws.amazon.com/efs/latest/ug/performance.html), and [Analyzing CloudBees CI's High Availability: Performance, Bottlenecks, and Conclusions](https://www.cloudbees.com/blog/analyzing-cloudbees-ci-high-availability-performance-bottlenecks-and).

## CloudBees CI trial license

This module runs with a [trial license for CloudBees CI](https://docs.cloudbees.com/docs/cloudbees-ci-migration/latest/trial-guide/).
Once the trial has expired, refer to [CloudBees CI license expiration FAQ](https://docs.cloudbees.com/docs/general-kb/latest/faqs/jenkins-enterprise-license-expiration-faq) to determine your next steps.

> [!NOTE]
> This addon appends the string `[EKS_TF_ADDON]` to the Trial License last name for telemetry purposes.

## Compatibility

The CloudBees CI add-on uses `helms release` for its resources definition, making it compatible with [AWS EKS Blueprint v4](https://github.com/aws-ia/terraform-aws-eks-blueprints/tree/v4.32.1) and [AWS EKS Blueprint v5](https://github.com/aws-ia/terraform-aws-eks-blueprints/tree/v5.0.0). For more information, refer to [Amazon EKS Blueprints for Terraform: v4 to v5 migration](https://aws-ia.github.io/terraform-aws-eks-blueprints/v4-to-v5/motivation/).

## Terraform documentation

<!-- BEGIN_TF_DOCS -->
### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cert_arn | AWS Certificate Manager (ACM) certificate for Amazon Resource Names (ARN). | `string` | n/a | yes |
| hosted_zone | Amazon Route 53 hosted zone name. | `string` | n/a | yes |
| trial_license | CloudBees CI trial license details for evaluation. | `map(string)` | n/a | yes |
| casc_secrets_file | Secrets .yml file path containing the names: values secrets. It is required when create_casc_secrets is enabled. | `string` | `"secrets-values.yml"` | no |
| create_casc_secrets | Create a Kubernetes basic secret for CloudBees CasC (cbci-sec-casc) and mount it into the operations center (/var/run/secrets/cbci). | `bool` | `false` | no |
| create_pi_ecr | Create Pod Identity for ECR. It requires the EKS Pod Identity agent running. | `bool` | `false` | no |
| create_pi_s3 | Create Pod Identity for s3. It requires the EKS Pod Identity agent running. | `bool` | `false` | no |
| create_prometheus_target | Creates a service monitor to discover the CloudBees CI Prometheus target dynamically. It is designed to be enabled with the AWS EKS Terraform Addon Kube Prometheus Stack. | `bool` | `false` | no |
| create_reg_secret | Create a Kubernetes dockerconfigjson secret for container registry authentication (cbci-sec-reg) for CI builds agents. | `bool` | `false` | no |
| helm_config | CloudBees CI Helm chart configuration. | `any` | <pre>{<br/>  "values": [<br/>    ""<br/>  ]<br/>}</pre> | no |
| pi_ecr_cbci_agents_ns | Kubernetes namespace for CloudBees CI ephemeral agents. | `string` | `"cbci-agents"` | no |
| pi_eks_cluster_name | EKS cluster name for Pod Identity. | `string` | `"acme-cluster"` | no |
| pi_s3_bucket_arn | S3 bucket arn for CBCI Backups and/or Workspace Cache | `string` | `"arn:aws:s3:::foo-bucket"` | no |
| pi_s3_bucket_cbci_prefix | S3 bucket path prefix for CBCI Backups and/or Workspace Cache | `string` | `"bar-prefix"` | no |
| pi_s3_sa_controllers | List of service account names for controllers that need S3 pod identity. Defaults to ['cjoc'] if not provided. | `list(string)` | <pre>[<br/>  "cjoc"<br/>]</pre> | no |
| prometheus_target_ns | Prometheus target namespace, designed to be enabled with the AWS EKS Terraform Addon Kube Prometheus Stack. It is required when prometheus_target is enabled. | `string` | `"observability"` | no |
| reg_secret_auth | Registry server authentication details for cbci-sec-reg secret. It is required when create_reg_secret is enabled. | `map(string)` | <pre>{<br/>  "email": "email@example.com",<br/>  "password": "changeme1234",<br/>  "server": "my-registry.acme:5000",<br/>  "username": "foo"<br/>}</pre> | no |
| reg_secret_ns | Agent namespace to allocate the cbci-sec-reg secret. It is required when create_reg_secret is enabled. | `string` | `"cbci"` | no |

### Outputs

| Name | Description |
|------|-------------|
| cbci_domain_name | Amazon Route 53 domain name to host CloudBees CI services. |
| cbci_liveness_probe_ext | Operations center service external liveness probe for the CloudBees CI add-on. |
| cbci_liveness_probe_int | Operations center service internal liveness probe for the CloudBees CI add-on. |
| cbci_namespace | Namespace for the CloudBees CI add-on. |
| cbci_oc_ing | Operations center Ingress for the CloudBees CI add-on. |
| cbci_oc_pod | Operations center pod for the CloudBees CI add-on. |
| cbci_oc_url | Operations center URL for the CloudBees CI add-on using a subdomain and certificates. |
| cbci_sec_casc | Optional. Kubernetes secrets name for CloudBees CI Casc. |
| cbci_sec_registry | Optional. Kubernetes secrets name for CloudBees CI agents to authenticate the registry. |
| merged_helm_config | (merged) Helm configuration for CloudBees CI. |
<!-- END_TF_DOCS -->

## Additional resources

- [CloudBees CI documentation](https://docs.cloudbees.com/docs/cloudbees-ci/latest/)
- [CloudBees CI release notes](https://docs.cloudbees.com/docs/release-notes/latest/cloudbees-ci/)
- [Architecture for CloudBees CI on modern cloud platforms](https://docs.cloudbees.com/docs/cloudbees-ci/latest/architecture/ci-cloud)
- [Amazon EKS Blueprints Addons](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/)
- [Amazon EKS Blueprints for Terraform](https://aws-ia.github.io/terraform-aws-eks-blueprints/)
- [Containers: Bootstrapping clusters with EKS Blueprints](https://aws.amazon.com/blogs/containers/bootstrapping-clusters-with-eks-blueprints/)
- [EKS Workshop](https://www.eksworkshop.com/)
