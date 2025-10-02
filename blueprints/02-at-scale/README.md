# CloudBees CI blueprint add-on: At scale

Once you have familiarized yourself with [CloudBees CI blueprint add-on: Get started](../01-getting-started/README.md), this blueprint presents a scalable architecture and configuration by adding:

- An [Amazon Elastic File System (Amazon EFS) drive](https://aws.amazon.com/efs/) that is required by CloudBees CI High Availability/Horizontal Scalability (HA/HS) controllers and is optional for non-HA/HS controllers.
- An [Amazon Simple Storage Service (Amazon S3) bucket](https://aws.amazon.com/s3/) to store assets from applications like CloudBees CI, Velero, and Fluent Bit.
- [Amazon Elastic Kubernetes Service (Amazon EKS) managed node groups](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html) for different workloads: shared services and CBCI applications.
- [Amazon Container Registry (Amazon ECR)](https://aws.amazon.com/ecr/) acts as a private container registry for CloudBees CI artifacts.
- [Amazon Backup](https://aws.amazon.com/backup/) to back up the Amazon EFS drive.
- [Amazon CloudWatch Logs](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html) to explode control plane logs and Fluent Bit logs.
- The following [Amazon EKS blueprints add-ons](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/):

  | Amazon EKS blueprints add-ons | Description |
  |-------------------------------|-------------|
  | [AWS EFS CSI Driver](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/aws-efs-csi-driver/)| Connects the Amazon Elastic File System (Amazon EFS) drive to the Amazon EKS cluster. |
  | [AWS for Fluent Bit](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/aws-for-fluentbit/)| Acts as an applications log router for log observability in CloudWatch. |
  | [Cluster Autoscaler](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/cluster-autoscaler/) | Watches Amazon EKS managed node groups to accomplish [CloudBees CI auto-scaling nodes on EKS](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/eks-auto-scaling-nodes) for Services |
  | [Karpenter](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/karpenter/) | Manages NodePools for Epheral Agents |
  | [Kube Prometheus Stack](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/kube-prometheus-stack/) | Observability backbone.|
  | [Metrics Server](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/metrics-server/) | This is a requirement for CloudBees CI HA/HS controllers for horizontal pod autoscaling.|
  | [Velero](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/velero/)| Backs up and restores Kubernetes resources and volume snapshots. It is only compatible with Amazon Elastic Block Store (Amazon EBS).|
  | [Bottlerocket Update Operator](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/bottlerocket/) | Coordinates Bottlerocket updates on hosts in a cluster. It is configured for CloudBees CI Applications and Agents Node Groups at a specific time according to `scheduler_cron_expression`, when the build workload is minimal (for example, on the weekend). In a case where the CI service cannot be interrupted at any time by the Update Operator, it could be excluded from planned updates by removing the [bottlerocket.aws/updater-interface-version=2.0.0](https://github.com/bottlerocket-os/bottlerocket-update-operator#label-nodes) label. [Cert-manager](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/cert-manager/) is required for the API server to use a CA certificate when communicating over SSL with the agents. |

- [Amazon EKS blueprints Helm Release add-on](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/helm-release/) is used to install the following applications:

  | Helm Chart | Description |
  |-------------------------------|-------------|
  | [Helm Openldap](https://github.com/jp-gouin/helm-openldap/tree/master) | LDAP server for Kubernetes. |
  | [Hashicorp Vault](https://github.com/hashicorp/vault-helm) | Secrets management system that is integrated via [CloudBees HashiCorp Vault Plugin](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-secure-guide/hashicorp-vault-plugin). |
  | [OTEL collector](https://grafana.com/oss/tempo/) | The collector for [Jenkins OpenTelemetry](https://plugins.jenkins.io/opentelemetry/) observability data. |
  | [Grafana Tempo](https://grafana.com/oss/tempo/) | Provides tracing backend for [Jenkins OpenTelemetry](https://plugins.jenkins.io/opentelemetry/). |
  | [Grafana Loki](https://grafana.com/oss/loki/) | Provides logs backend for [Jenkins OpenTelemetry](https://plugins.jenkins.io/opentelemetry/). |

- Cloudbees CI uses [Configuration as Code (CasC)](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-oc/casc-intro) (refer to the [casc](cbci/casc) folder) to enable [exciting new features for streamlined DevOps](https://www.cloudbees.com/blog/cloudbees-ci-exciting-new-features-for-streamlined-devops) and other enterprise features, such as [CloudBees CI hibernation](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/managing-controllers#hibernation-managed-controllers).
  - The CloudBees operations center is using the [CasC Bundle Retriever](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-oc/bundle-retrieval-scm).
  - Managed controller configurations are managed from the operations center using [source control management (SCM)](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-controller/add-bundle#_adding_casc_bundles_from_an_scm_tool).
  - The managed controllers are using [CasC bundle inheritance](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-controller/advanced#_configuring_bundle_inheritance_with_casc) (refer to the [parent](cbci/casc/mc/mc-parent) folder). This "parent" bundle is inherited by two types of "child" controller bundles: `ha` and `none-ha`, to accommodate [considerations about HA controllers](https://docs.cloudbees.com/docs/cloudbees-ci/latest/ha/ha-considerations).

> [!TIP]
> A [resource group](https://docs.aws.amazon.com/ARG/latest/userguide/resource-groups.html) is also included, to get a full list of all resources created by this blueprint.

## Architecture

This blueprint divides scalable node groups for different types of workloads using different Scaling Engines.

- **Cluster Autoscaler**: For services workloads using [Bottlerocket OS](https://aws.amazon.com/bottlerocket/) AMI type.
  - Shared node groups (role: `shared`) `x86` arch.
  - CloudBees CI Services (role: `cb-apps`) [AWS Graviton Processor](https://aws.amazon.com/ec2/graviton/) `arm64` arch.
- **Karpenter**: For ephemeral workloads
  - Linux (role: `linux-builds`): Using [Bottlerocket OS](https://aws.amazon.com/bottlerocket/) with preferences for [AWS Graviton Processor](https://aws.amazon.com/ec2/graviton/) and `spot` capacity type. But ready for fallback to other types.
  - Windows (role: `windows-builds`): Using Windows 2019 or 2022 AMI type and `amd64` arch with preferences for `spot` capAcacity type but ready for fallback to on-demand instances.

> [!IMPORTANT]
> The launch time for Linux containers is faster than Windows containers. This can be improved by using a cache container image strategy. Refer to [Speeding up Windows container launch times with EC2 Image builder and image cache strategy](https://aws.amazon.com/blogs/containers/speeding-up-windows-container-launch-times-with-ec2-image-builder-and-image-cache-strategy/) and more about [Windows Container Best Practices](https://aws.github.io/aws-eks-best-practices/windows/docs/ami/). Another potential alternative is to use Windows VMs with a [shared agent](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/shared-agents).

> [!NOTE]
> The minimum required of managed node groups is one to place Karpenter controllers and CoreDNS. The rest of the services workloads, including CloudBees CI, can be migrated to Karpenter NodeGroups. In order to avoid services disruptions by Karpenter consolidation, there are different strategies to be considered:
> - For services with one replica only: Defining `consolidationPolicy: WhenEmpty` for NodePools and/or using `karpenter.sh/do-not-disrupt: "true"` labels for Pods.
> - For services with multiple replicas: Use [PodDisruptionBudgets (PDBs)](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/#pod-disruption-budgets) to limit the number of pods that can be disrupted at any given time. This option can be interesting in combination with spot capacity type.

> [!TIP]
> For more info on karpenter patterns/scenarios, refer to [AWS Karpenter Blueprints](https://github.com/aws-samples/karpenter-blueprints)

Storage configuration follows best practices for Cost Optimization:
  - EBS: `gp3` is set as the default storage class.
  - No HA/HS controllers use `gp3-aza` (an Amazon EBS type which is tightened to Availability Zone A to avoid issue [#195](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/issues/195)).
  - Intelligent tiering definition for EFS, S3 and AWS Backups.

![Architecture](img/at-scale.architect.drawio.svg)

### Workloads

![K8sApps](img/at-scale.k8s.drawio.svg)

CloudBees CI uses [Pod identity](https://aws.amazon.com/blogs/aws/amazon-eks-pod-identity-simplifies-iam-permissions-for-applications-on-amazon-eks-clusters/) to acquire different AWS permissions per namespaces and service accounts:

- `services_s3`: S3 services for backup, restore and cache operations.
- `agent_ecr`: ECR services for private CI/CD container images management.

> [!IMPORTANT]
> Known issues: Operation Center pod requires to be recreated to get injected AWS credentials.

CloudBees CI uses a couple of Kubernetes secrets for different purposes depending

- `cbci`: for masking secrets for CasC configuration.
- `cbci-agents`: Dockerhub services for public CI/CD container images management.

## Terraform documentation

<!-- BEGIN_TF_DOCS -->
### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| hosted_zone | Amazon Route 53 hosted zone. CloudBees CI applications are configured to use subdomains in this hosted zone. | `string` | n/a | yes |
| trial_license | CloudBees CI trial license details for evaluation. | `map(string)` | n/a | yes |
| aws_region | AWS region to deploy resources to. It requires a minimum of three availability zones. | `string` | `"us-west-2"` | no |
| cbci_casc_path_controller | Path within the Git repository that contains the CloudBees CI controllers. | `string` | `"blueprints/02-at-scale/cbci/mc"` | no |
| cbci_casc_path_shared_library | Path within the Git repository that contains the CloudBees CI shared library. | `string` | `"blueprints/02-at-scale/cbci/shared-lib"` | no |
| ci | Running in a CI service versus running locally. False when running locally, true when running in a CI service. | `bool` | `false` | no |
| dh_reg_secret_auth | Docker Hub registry server authentication details for cbci-sec-reg secret. | `map(string)` | <pre>{<br/>  "email": "email@example.com",<br/>  "password": "changeme1234",<br/>  "username": "foo"<br/>}</pre> | no |
| oc_casc_scm_branch | Branch of the Git repository that contains the CloudBees CI CasC bundle configuration for the operations center. | `string` | `"develop"` | no |
| oc_casc_scm_bundle_path | Path within the Git repository that contains the CloudBees CI CasC bundle configuration for the operations center. | `string` | `"blueprints/02-at-scale/cbci/casc/oc"` | no |
| oc_casc_scm_polling_interval | Polling interval for the Git repository that contains the CloudBees CI CasC bundle configuration for the operations center. | `string` | `"PT20M"` | no |
| oc_casc_scm_repo_url | URL of the Git repository that contains the CloudBees CI CasC bundle configuration for the operations center. | `string` | `"https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon.git"` | no |
| suffix | Unique suffix to assign to all resources. When adding the suffix, changes are required in CloudBees CI for the validation phase. | `string` | `""` | no |
| tags | Tags to apply to resources. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
|------|-------------|
| acm_certificate_arn | AWS Certificate Manager (ACM) certificate for Amazon Resource Names (ARN). |
| aws_backup_efs_protected_resource | AWS description for the Amazon EFS drive that is used to back up protected resources. |
| aws_region | AWS region. |
| cbci_agent_linuxtempl_events | Retrieves a list of events related to Linux template agents. |
| cbci_agent_sec_reg | Retrieves the container registry secret deployed in the agents namespace. |
| cbci_agent_windowstempl_events | Retrieves a list of events related to Windows template agents. |
| cbci_agents_pods | Retrieves a list of agent pods running in the agents namespace. |
| cbci_controller_b_s3_build | team-b hibernation monitor endpoint to the build s3-WScacheAndArtifacts. It expects CBCI_ADMIN_TOKEN as the environment variable. |
| cbci_controller_c_hpa | team-c horizontal pod autoscaling. |
| cbci_controller_c_windows_node_build | team-c hibernation monitor endpoint to the Windows build nodes. It expects CBCI_ADMIN_TOKEN as the environment variable. |
| cbci_controllers_pods | Operations center pod for the CloudBees CI add-on. |
| cbci_helm | Helm configuration for the CloudBees CI add-on. It is accessible via state files only. |
| cbci_liveness_probe_ext | Operations center service external liveness probe for the CloudBees CI add-on. |
| cbci_liveness_probe_int | Operations center service internal liveness probe for the CloudBees CI add-on. |
| cbci_namespace | Namespace for the CloudBees CI add-on. |
| cbci_oc_export_admin_api_token | Exports the operations center cbci_admin_user API token to access the REST API when CSRF is enabled. It expects CBCI_ADMIN_CRUMB as the environment variable. |
| cbci_oc_export_admin_crumb | Exports the operations center cbci_admin_user crumb, to access the REST API when CSRF is enabled. |
| cbci_oc_ing | Operations center Ingress for the CloudBees CI add-on. |
| cbci_oc_pod | Operations center pod for the CloudBees CI add-on. |
| cbci_oc_take_backups | Operations center cluster operations build for the on-demand back up. It expects CBCI_ADMIN_TOKEN as the environment variable. |
| cbci_oc_url | Operations center URL for the CloudBees CI add-on. |
| efs_access_points | Amazon EFS access points. |
| efs_arn | Amazon EFS ARN. |
| eks_cluster_arn | Amazon EKS cluster ARN. |
| eks_cluster_name | Amazon EKS cluster name. |
| global_password | Random string that is used as the global password. |
| grafana_url | Grafana URL. |
| kubeconfig_add | Adds kubeconfig to the local configuration to access the Kubernetes API. |
| kubeconfig_export | Exports the KUBECONFIG environment variable to access the Kubernetes API. |
| loki_labels | Lists all labels ingested in Loki. |
| prometheus_active_targets | Checks active Prometheus targets from the CloudBees operations center. |
| prometheus_dashboard | Provides access to Prometheus dashboards. |
| s3_cbci_arn | CloudBees CI Amazon S3 bucket ARN. |
| s3_cbci_name | CloudBees CI Amazon S3 bucket name. It is required by CloudBees CI for workspace caching and artifact management. |
| s3_list_objects | Recursively lists all objects stored in the Amazon S3 bucket. |
| tempo_tags | Lists all tags ingested in Tempo. |
| vault_configure | Configures the vault with initial secrets and creates the application role for integration with CloudBees CI (role-id and secret-id). It requires unseal keys and the root token from the vault_init output. |
| vault_dashboard | Provides access to Hashicorp Vault dashboard. It requires the root token from the vault_init output. |
| vault_init | Initialization of the vault service. |
| vault_init_log_file | Vault initialization log file. |
| velero_backup_on_demand | Takes an on-demand Velero backup from the schedule for the selected controller that is using block storage. |
| velero_backup_schedule | Creates a Velero backup schedule for the selected controller that is using block storage, and then deletes the existing schedule, if it exists. |
| velero_restore | Restores the selected controller that is using block storage from a backup. |
| vpc_arn | VPC ARN. |
<!-- END_TF_DOCS -->

## Prerequisites

This blueprint uses [DockerHub](https://hub.docker.com/) as a container registry service. Note that an existing DockerHub account is required (username, password, and email).

> [!TIP]
> Use `docker login` to validate username and password.

## Deploy

When preparing to deploy, you must complete the following steps:

1. Customize your Terraform values by copying `.auto.tfvars.example` to `.auto.tfvars`.
1. Initialize the root module and any associated configuration for providers.
1. Create the resources and deploy CloudBees CI to an EKS cluster. Refer to [Amazon EKS Blueprints for Terraform - Deploy](https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#deploy).

For more information, refer to [The Core Terraform Workflow](https://www.terraform.io/intro/core-workflow) documentation.

> [!TIP]
> The `deploy` phase can be orchestrated via the companion [Makefile](../Makefile).

## Validate

Once the blueprint has been deployed, you can validate it.

### Kubeconfig

Once the resources have been created, a `kubeconfig` file is created in the [/k8s](k8s) folder. Issue the following command to define the [KUBECONFIG](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/#the-kubeconfig-environment-variable) environment variable to point to the newly generated file:

   ```sh
   eval $(terraform output --raw kubeconfig_export)
   ```

If the command is successful, no output is returned.

### CloudBees CI

#### Authentication and authorization

1. Complete the steps to [validate CloudBees CI](../01-getting-started/README.md#cloudbees-ci), if you have not done so already.
1. Authentication in this blueprint is based on LDAP using the `cn` user (available in [k8s/openldap-stack-values.yml](./k8s/openldap-stack-values.yml)) and the global password. The authorization level defines a set of permissions configured using [RBAC](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-secure-guide/rbac). Additionally, the operations center and controller use [single sign-on (SS0)](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-secure-guide/using-sso), including a [fallback mechanism](https://docs.cloudbees.com/docs/cloudbees-ci-kb/latest/operations-center/how-ldap-plugin-works-on-cjoc-sso-context) that is enabled by default. Issue the following command to retrieve the global password (valid for all users):

   ```sh
   eval $(terraform output --raw global_password)
   ```

   There are differences in CloudBees CI permissions and folder restrictions when signed in as a user of the Admin group versus the Development group. For example, only Admin users have access to the validation jobs.

#### Configuration as Code (CasC)

1. CasC is enabled for the [operations center](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-oc/) (`cjoc`) and [controllers](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-controller/) (`team-b` and `team-c-ha`). `team-a` is not using CasC, to illustrate the difference between the two approaches. Issue the following command to verify that all controllers are running:

   ```sh
   eval $(terraform output --raw cbci_controllers_pods)
   ```

   If successful, it should indicate that 2 replicas are running for `team-c-ha` since [CloudBees CI HA/HS](https://docs.cloudbees.com/docs/cloudbees-ci/latest/ha-install-guide/) is enabled on this controller.

1. Issue the following command to verify that horizontal pod autoscaling is enabled for `team-c-ha`:

   ```sh
   eval $(terraform output --raw cbci_controller_c_hpa)
   ```

1. [Validating bundles prior to update](https://docs.cloudbees.com/docs/cloudbees-ci/latest/casc-oc/update-bundle#_validating_bundles_prior_to_update) is orchestrated via `validate-all-casc-bundles` jobs using as parameters API Token from admin user `admin_cbci_a` (see [builds](#builds) section) and the branch to validate.

#### Secrets management

##### Kubernetes secret

This blueprint uses Kubernetes secrets for different purposes.

> [!NOTE]
> - Beyond the CloudBees CI add-on that is used for demo purposes, Kubernetes secrets can be managed via [External Secret Operators](https://aws-ia.github.io/terraform-aws-eks-blueprints-addons/main/addons/external-secrets/).
> - Kubernetes secrets can be also be retrieved as Jenkins credentials using the [Kubernetes Credentials Provider plugin](https://jenkinsci.github.io/kubernetes-credentials-provider-plugin/).

###### CasC secrets

The secrets key/value file defined in [k8s/secrets-values.yml](k8s/secrets-values.yml) is converted into a Kubernetes secret (`cbci-sec-casc`) and mounted into `/run/secrets/` for the operations center and controllers to be consumed via CloudBees CasC. Refer to [Configuration as Code - Handling Secrets - Kubernetes Secrets](https://github.com/jenkinsci/configuration-as-code-plugin/blob/master/docs/features/secrets.adoc#kubernetes-secrets) for more information.

###### Container registry secrets

DockerHub authentication is stored as Kubernetes secrets (`cbci-agent-sec-reg`) and mounted to [Kaniko agent containers](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/using-kaniko) to build and push images to this registry. The secret is created using the `dh_reg_secret_auth` variable.

```sh
   eval $(terraform output --raw cbci_agent_sec_reg)
```

> [!NOTE]
> Amazon Elastic Container Registry (Amazon ECR) authentication is done via pod identity  `agent_ecr`.

##### HashiCorp Vault

HashiCorp Vault is used as a credential provider for CloudBees CI Pipelines in this blueprint.

1. Initialize Hashicorp Vault. Keep in a safe place Admin Token and Unseal Keys (saved in `k8s/vault-init.log`).

   ```sh
   eval $(terraform output --raw vault_init)
   ```

1. Run the configure Hashicorp Vault script. It configures Vault with initial secrets and creates `approle` for integration with CloudBees CI (role-id and secret-id)

   ```sh
   eval $(terraform output --raw vault_configure)
   ```

1. Access the HashiCorp Vault UI by issuing the following command. Enter the root token to log in from the _step 1_.

   ```sh
   eval $(terraform output --raw vault_dashboard)
   ```

   If successful, the Vault web service should be available at `http://localhost:50003` and you can view the secrets that were created in _step 2_.

1. Sign in to the CloudBees CI operations center as a user with the admin role.

1. Navigate to **Manage Jenkins > Credentials Providers > HashiCorp Vault Credentials Provider** and complete the configuration for the CloudBees CI Vault Plugin by entering the role ID and secret ID for the `cbci-oc` application role from _step 1_.

1. Select **Test Connection** to verify the inputs are correct.

1. Move to `team-b` or `team-c-ha` to run the Pipeline (**admin > validations > vault-credentials**) and validate that credentials are fetched correctly from the Hashicorp Vault.

> [!NOTE]
> Hashicorp Vault can be also be configured to be used for [Configuration as Code - Handling Secrets - Vault](https://github.com/jenkinsci/configuration-as-code-plugin/blob/master/docs/features/secrets.adoc#hashicorp-vault-secret-source).

#### Builds

##### Build Node Pools

1. For the following validations, builds will be triggered remotely. Start by issuing the following command to retrieve an [API token](https://docs.cloudbees.com/docs/cloudbees-ci-api/latest/api-authentication) for the `admin_cbci_a` user with the correct permissions for the required actions:

   ```sh
   eval $(terraform output --raw cbci_oc_export_admin_crumb) && \
   eval $(terraform output --raw cbci_oc_export_admin_api_token) && \
   printenv | grep CBCI_ADMIN_TOKEN
   ```

   If the command is not successful, issue the following command to validate that DNS propagation has been completed:

   ```sh
   eval $(terraform output --raw cbci_liveness_probe_ext)
   ```

1. Once you have retrieved the API token, issue the following commands to trigger builds using the [POST queue for hibernation API endpoint](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/managing-controllers#_post_queue_for_hibernation). If successful, an `HTTP/2 201` response is returned, indicating the REST API call has been correctly received by the CloudBees CI controller.

   - For Linux node pools use:

      ```sh
      eval $(terraform output --raw cbci_controller_b_s3_build)
      ```

      It triggers the `s3-WScacheAndArtifacts` Pipeline from the `team-b` controller. This pipeline validates S3 integrations in parallel for [CloudBees workspace caching](https://docs.cloudbees.com/docs/cloudbees-ci/latest/pipelines/cloudbees-cache-step) (using `linux-mavenAndKaniko-L`) and the [S3 artifact manager](https://plugins.jenkins.io/artifact-manager-s3/) (using `linux-mavenAndKaniko-XL`).

      Once the second build is complete, you can find the read cache operation at the beginning of the build logs and the write cache operation at the end of the build logs.

   - For Windows node pool use:

      ```sh
      eval $(terraform output --raw cbci_controller_c_windows_node_build)
      ```

      It triggers the `windows` builds Pipeline from the `team-c-ha` controller.

      Note that the first build for a new Windows image container can take up to 10 minutes to run; subsequent builds should take seconds to run. This behavior can be improved, as explained in the section [Architecture](#architecture).

2. Right after triggering the builds, issue the following to validate pod agent provisioning to build the Pipeline code:

   ```sh
   eval $(terraform output --raw cbci_agents_pods)
   ```

3. Check build logs by signing in to the `team-b` and `team-c-ha` controllers, respectively. Navigate to the Pipeline jobs and select the first build, indicated by the `#1` build number. [CloudBees Pipeline Explorer](https://docs.cloudbees.com/docs/cloudbees-ci/latest/pipelines/cloudbees-pipeline-explorer-plugin) is enabled by default.

##### Container Registry

This blueprint use a couple of container registries for different purposes:

- The public registry uses DockerHub.
- The private registry uses AWS ECR.

> [!NOTE]
> Other Container Registry services can be used for the same purposes.

1. In the CloudBees CI UI, sign in to the `team-b` or `team-c-ha` controllers with admin access.
1. Navigate to the **admin > validations > kaniko** Pipeline.
1. Using parameters, enter an existing DockerHub organization and an existing Amazon ECR repository to test that building and pushing to all repositories works as expected.

> [!NOTE]
> Besides Kaniko, there are [other alternative tools](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/using-kaniko#_alternatives) for building images in K8s.

##### Pipeline Governance

A [Jenkins Shared Library](https://www.jenkins.io/doc/book/pipeline/shared-libraries/) is define [here](./cbci/shared-lib/) to collect functions, resources, and steps following best practices that can be reused across the organization.

Additionally, [CloudBees Pipeline Policies](https://docs.cloudbees.com/docs/cloudbees-ci/latest/pipelines/pipeline-policies) are enable to ensure pipelines are compliant with the organization’s policies.

- For All controllers: timeout and retry policies are configured.
- For HA controllers: HA compatible steps are configured.

Steps:

1. In the CloudBees CI UI, sign in to the `team-b` or `team-c-ha` controllers with admin or developer access.
2. Navigate to the **admin > validations** and run one build for any of the pipelines
3. Check  `Pipeline Policies Overview` for the build view.

#### Back up and restore

For backup and restore operations, you can use the [preconfigured CloudBees CI Cluster Operations job](#cloudbees-ci-backup) to automatically perform a daily backup, which can be used for Amazon EFS and Amazon EBS storage.

[Velero](#velero) is an alternative for services only for controllers using Amazon EBS. Velero commands and configuration in this blueprint follow [Using Velero back up and restore Kubernetes cluster resources](https://docs.cloudbees.com/docs/cloudbees-ci/latest/backup-restore/velero-dr). There is no alternative for services using Amazon EFS storage. Although [AWS Backup](https://aws.amazon.com/backup/) includes the Amazon EFS drive as a protected resource, there is not currently a best practice to dynamically restore Amazon EFS PVCs. For more information, refer to [Issue 39](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/issues/39).

> [!NOTE]
> - An installation that has been completely converted to CasC may not need traditional backups; a restore operation could consist simply of running a CasC bootstrap script. This is only an option if you have translated every significant system setting and job configuration to CasC. Even then, it may be desirable to perform a filesystem-level restore from backup to preserve transient data, such as build history.

##### CloudBees CI Backup

The [CloudBees Backup plugin](https://docs.cloudbees.com/docs/cloudbees-ci/latest/backup-restore/cloudbees-backup-plugin) is enabled for all controllers and the operations center using [Amazon S3 as storage](https://docs.cloudbees.com/docs/cloudbees-ci/latest/backup-restore/cloudbees-backup-plugin#_amazon_s3). The preconfigured **backup-all-controllers** [Cluster Operations](https://docs.cloudbees.com/docs/cloudbees-ci/latest/cloud-admin-guide/cluster-operations) job is scheduled to run daily from the operations center to back up all controllers.

To view the **backup-all-controllers** job:

1. Sign in to the CloudBees CI operations center UI as a user with **Administer** privileges. Note that access to back up jobs is restricted to admin users via RBAC.
1. From the operations center dashboard, select **All** to view all folders on the operations center.
1. Navigate to the **admin** folder, and then select the **backup-all-controllers** Cluster Operations job.

For restore operations, download the backup point and follow [Rescue Pod](https://docs.cloudbees.com/docs/cloudbees-ci/latest/backup-restore/kubernetes#_use_a_rescue_pod) methodology.

##### Velero

Issue the following command to create a Velero backup schedule for selected controller `team-b` (this can also be applied to `team-a`):

   ```sh
   eval $(terraform output --raw velero_backup_schedule)
   ```

Issue the following command to take an on-demand Velero backup for a specific point in time for `team-b` based on the schedule definition:

>[!NOTE]
> When using this CloudBees CI add-on, you must [create at least one Velero backup schedule](#velero) prior to taking an on-demand Velero backup.

   ```sh
   eval $(terraform output --raw velero_backup_on_demand)
   ```

Issue the following command to restore the controller from the last backup:

   ```sh
   eval $(terraform output --raw velero_restore)
   ```

### Observability

> [!IMPORTANT]
> Regarding the observability stack described in the following sections, note that the CloudBees Prometheus plugin is a CloudBees Tier 1 plugin, while the Jenkins OpenTelemetry plugin is a Tier 3 plugin. For more information, refer to the  [CloudBees plugin support policies](https://docs.cloudbees.com/docs/cloudbees-common/latest/plugin-support-policies).

#### Datasources

##### Metrics

Prometheus is used to store metrics that are retrieved from the [Jenkins Metrics plugin](https://plugins.jenkins.io/metrics/) and the [Jenkins OpenTelemetry plugin](https://github.com/jenkinsci/opentelemetry-plugin/blob/main/docs/monitoring-metrics.md).

Grafana imports Prometheus as a datasource and provides metrics dashboards for CloudBees CI.

1. Issue the following command to verify that the CloudBees CI targets are connected to Prometheus:

   ```sh
   eval $(terraform output --raw prometheus_active_targets) | jq '.data.activeTargets[] | select(.labels.container=="jenkins") | {job: .labels.job, instance: .labels.instance, status: .health}'
   ```

1. Issue the following command to access Kube Prometheus Stack dashboards from your web browser and verify that targets are correctly collecting metrics.

   ```sh
   eval $(terraform output --raw prometheus_dashboard)
   ```  

   If successful, the Prometheus web service is available at `http://localhost:50001` and you can view the configured alerts for CloudBees CI. Additionally, you can select **Status > Targets** to show targets with an `UP` status.

1. Issue the following command to access the Grafana URL. For the username, use `admin` and set the password using the `global_password` terraform variable:

   ```sh
   eval $(terraform output --raw grafana_url)
   ```

Additionally, [Amazon CloudWatch Container Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights.html) for all your containerized applications and microservices.

>[!NOTE]
>[CloudWatch agent with Prometheus metrics collection on Amazon EKS and Kubernetes clusters](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights-Prometheus-Setup.html) can be enabled to collect Jenkins Metrics in prometheus format.

##### Tracing

Tempo is used as the Tracing/APM backend for Jenkins tracing data via the Jenkins OpenTelemetry plugin: [HTTP](https://github.com/jenkinsci/opentelemetry-plugin/blob/main/docs/http-requests-traces.md) and [Jobs](https://github.com/jenkinsci/opentelemetry-plugin/blob/main/docs/job-traces.md).

Grafana imports Tempo as a datasource and provides tracing dashboards per a CI/CD pipeline Trace ID.

In CloudBees CI, the Jenkins OpenTelemetry plugin is configured to use Grafana as a visualization backend. Then, it offers a **View pipeline with Grafana** link for every pipeline run, which redirects to Grafana Explorer using Tempo as a datasource and passing a Trace ID. Other system traces can be visualized in Grafana Explorer as well.

##### Logs

###### Build Logs

The recommended approach for build logs is using [CloudBees Pipeline Explorer](https://docs.cloudbees.com/docs/cloudbees-ci/latest/pipelines/cloudbees-pipeline-explorer-plugin).

> [!IMPORTANT]
> Although [pipeline build logs can be sent to external storage via the Jenkins OpenTelemetry plugin](https://github.com/jenkinsci/opentelemetry-plugin/blob/main/docs/build-logs.md), it is not compatible with CloudBees Pipeline Explorer.

###### Container logs

Fluent Bit acts as a router for container logs.

- Short-term logs and log aggregation systems:

  - [Amazon CloudWatch Logs](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html) group: Stores log streams for all the Kubernetes services running in the cluster, including CloudBees CI applications and agents in `/aws/eks/<CLUSTER_NAME>/aws-fluentbit-logs`.

   ```sh
   eval $(terraform output --raw aws_logstreams_fluentbit) | jq '.[] '
   ```

  - CloudWatch log group: Stores control plane logs in `/aws/eks/CLUSTER_NAME>/cluster`.

  - [Loki](https://grafana.com/oss/loki/):  In Grafana, navigate to the **Explore** section, select **Loki** as the datasource, filter by `com_cloudbees_cje_tenants`, and then select a CloudBees CI application log.

- Long-term logs are stored in an Amazon S3 bucket under the `fluentbit` path.

###### Audit logs

[Audit Trail plugin](https://plugins.jenkins.io/audit-trail/) is enabled for all controllers and the operations center to track updates via the UI and REST API. Observability Grafana Dashboards includes a widget for audit logs.

#### Dashboards

There are a couple of CloudBees CI dashboards available in [Grafana Labs - Dashboards](https://grafana.com/grafana/dashboards) designed and tested for this blueprint:

- [Infra and Service Health Checks](https://grafana.com/grafana/dashboards/23781-cloudbees-ci-infra-and-service-health-checks/): It is designed to monitor infrastructure and service health, giving visibility into Kubernetes resource usage, JVM behaviour, HTTP traffic, system-level events, and user update auditing.
- [Build Performance](https://grafana.com/grafana/dashboards/23783-cloudbees-ci-build-performance/): This dashboard provides deep insights into build performance, pipelines, and agent usage. It includes key build KPIs and OpenTelemetry-based pipeline tracing.

Go to the Grafana UI, navigate to the **Dashboards** section, and import the dashboards using their IDs or JSON definition.

>[!NOTE]
> Run the `admin/load-test` Pipeline on team-b or team-c-ha to populate build metrics.

## Destroy

To tear down and remove the resources created in the blueprint, refer to [Amazon EKS Blueprints for Terraform - Destroy](https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#destroy).

> [!TIP]
> - To avoid [#165](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/issues/165), run `kube-prometheus-destroy.sh` after destroying the EKS cluster.
> - The `destroy` phase can be orchestrated via the companion [Makefile](../Makefile).
