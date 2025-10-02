# Contribute

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Design principles](#design-principles)
  - [Changing the default repo and branch for GitOps](#changing-the-default-repo-and-branch-for-gitops)
- [Release process](#release-process)
- [Report bugs and feature requests](#report-bugs-and-feature-requests)
- [Contribute via pull requests](#contribute-via-pull-requests)
  - [Pre-commits: Linting, formatting and secrets scanning](#pre-commits-linting-formatting-and-secrets-scanning)
  - [Blueprint Terraform CI pipeline](#blueprint-terraform-ci-pipeline)
    - [Prerequisites](#prerequisites)
- [Release](#release)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

This document provides guidelines for contributing to the CloudBees CI add-on for Amazon EKS blueprints.

## Design principles

- It follows the same approach as the [Terraform AWS EKS Blueprints for Terraform Patterns](https://aws-ia.github.io/terraform-aws-eks-blueprints/).
- The blueprints use a monorepo configuration to ensure that all the components are versioned together.
- In a production environment, it would be expected to have a single repository for the blueprints, and another repositories for the CloudBees CI configuration as code (CasC) bundles and shared libraries (see [At scale blueprint](blueprints/02-at-scale)).
- This monorepo approach is managed using [Spare Checkouts](https://github.blog/open-source/git/bring-your-monorepo-down-to-size-with-sparse-checkout/).

### Changing the default repo and branch for GitOps

The `02-at-scale` blueprint relies on a repository and branch for some of its configuration. The following variables found in the [./blueprints/02-at-scale/.auto.tfvars.example](./blueprints/02-at-scale/.auto.tfvars.example) make it possible to switch between branches when you are making updates to the CasC bundles and shared libraries.

```sh
# Required variables pointing to the monorepo and branch
# oc_casc_scm_repo_url = "https://github.com/cloudbees-oss/terraform-aws-cloudbees-ci-eks-addon.git"
# oc_casc_scm_branch    = "develop"

# Optional variables to further tweak configuration
# oc_casc_scm_bundle_path = "blueprints/02-at-scale/cbci/casc/oc"
# oc_casc_scm_polling_interval = "PT2M"
# cbci_casc_path_controller = "blueprints/02-at-scale/cbci/casc/mc"
# cbci_casc_path_shared_library = "blueprints/02-at-scale/cbci/shared-lib"
```

So in this case, simply:

- fork this repository
- create a new branch from develop
- change the repo and branch in the copied `.auto.tfvars` to match your fork and branch

## Release process

**1.** Submit pull requests against the `develop` branch and release from the `main` branch.

- As pre-requisite to merge against the `main` or `develop` branch, run successfully `make test-all` which includes sequential `deploy`, `validate` and `destroy`  steps for all the blueprints.
- `main` branch:
  - It is the stable branch and is used for releases.
  - Before merging a pull request, the CloudBees Center of Excellence (CoE) team must validate the changes.
  - Requirements:
    - The `source` field in the `eks_blueprints_addon_cbci` at blueprints must point to the remote [terraform registry version](https://registry.terraform.io/modules/cloudbees/cloudbees-ci-eks-addon/aws/latest) and `version >= "x.y.z"`. `"x.y.z"` matches with the latest release. It is important for the telemetry in [https://registry.terraform.io/modules/cloudbees/cloudbees-ci-eks-addon/aws/latest](https://registry.terraform.io/modules/cloudbees/cloudbees-ci-eks-addon/aws/latest).
    - The CasC bundles SCM configuration must point to the [https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon) repository and its `main` branch.
- `develop` branch:
  - It is the integration branch, and is used for testing new features and updates before merging them into the `main` branch.
  - Requirements:
    - The `source` field in the `eks_blueprints_addon_cbci` in the blueprints folder must point to the local root of the [terraform-aws-cloudbees-ci-eks-addon](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon) repository (for example, `source = "../../"`).
    - The CasC bundles SCM configuration must point to the `develop` branch in the [terraform-aws-cloudbees-ci-eks-addon](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon) repository.

**2.** Once the pull request from `develop` is merged into the `main` branch, make a direct push to the main branch to update `version >= "x.y.z"`. With the values `"x.y.z"` matching with the **previous** version of the helm chart of CloudBees Core CI. Why? Until the release is not published, the version in the terraform registry is not updated.

**3.** Publish the draft release in the [Releases](https://github.com/cloudbees-oss/terraform-aws-cloudbees-ci-eks-addon/releases) making sure the `tag` and `release title` match the version of the helm chart of CloudBees Core CI.

## Report bugs and feature requests

CloudBees welcomes you to use the GitHub issue tracker to report bugs or suggest features.

When filing an issue:

1. Check existing open and recently closed [issues](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/issues) to ensure the issue has not already been reported.
2. Review the upstream repositories:
   - [aws-ia/terraform-aws-eks-blueprints](https://github.com/aws-ia/terraform-aws-eks-blueprints/issues)
   - [aws-ia/terraform-aws-eks-blueprints-addons](https://github.com/aws-ia/terraform-aws-eks-blueprints-addons/issues)
3. Try to include as much information as you can. Details like the following are incredibly useful:
   - A reproducible test case or series of steps
   - The version of code being used
   - Any modifications you have made relevant to the bug
   - Anything unusual about your environment or deployment

## Contribute via pull requests

Contributions via pull requests are appreciated. Before submitting a pull request, please ensure that you:

1. Are working against the latest source on the `develop` branch.
2. Check existing open, and recently merged, pull requests to make sure someone else has not already addressed the problem.
3. Open an issue to discuss any significant work; we do not want your time to be wasted.

To submit a pull request:

1. Fork the repository.
2. Create a feature branch based on the `develop` branch.
3. Modify the source and focus on the specific change you are contributing. For example, if you reformat all the code, it is hard for reviewers to focus on your specific change.
4. **Ensure that local tests pass**. Local tests can be orchestrated via the companion [Makefile](blueprints/Makefile).
5. Make commits to your fork using clear commit messages.
6. Submit a pull request against the `develop` branch and answer any default questions in the pull request interface.
7. Pay attention to any automated CI failures reported in the pull request, and stay involved in the conversation.

> [!IMPORTANT]
> If you make updates to embedded repository (for example, CasC bundles), you must push the changes to the public upstream (repository/branch) before running `terraform apply` locally. The endpoint and/or branch can be updated via the terraform variables mentioned in [Changing the default repo and branch for GitOps](#changing-the-default-repo-and-branch-for-gitops).

### Pre-commits: Linting, formatting and secrets scanning

Many of the files in the repository can be linted or formatted to maintain a standard of quality. Additionally, secret leaks are watched via [gitleaks](https://github.com/zricethezav/gitleaks#pre-commit) and [git-secrets](https://github.com/awslabs/git-secrets).

1. When working with the repository for the first time, you must install `pre-commit`. For more information, refer to [pre-commit installation](https://pre-commit.com/#installation).
2. Run `pre-commit run --all-files`. Run this command again if the automated checks fail when you create a pull request.

### Blueprint Terraform CI pipeline

Validate your pull request changes inside the blueprint agent described in the [Dockerfile](.docker/agent). It is the same agent used for the CI pipeline [bp-agent-ecr.yaml](.cloudbees/workflows/bp-agent-ecr.yaml).

> [!NOTE]
> The agent and dependencies can be automated using the [Makefile](blueprints/Makefile) at the root of the project, under the target `bpAgent-dRun`. It is the same Makefile used in the CloudBees CI pipeline.

The [bp-tf-ci.yaml](.cloudbees/workflows/bp-tf-ci.yaml) blueprints are orchestrated into the [CloudBees platform](https://www.cloudbees.com/products/saas-platform) inside the [CloudBees Professional Services (PS) sub-organization](https://cloudbees.io/orgs/cloudbees~professional-services/components/94c50dcf-125e-4767-b9c5-58d6d669a1f6/runs).

> [!NOTE]
> The pipeline triggers on `push` events only, and does not trigger for `pull_requests`. Although the `pull_requests` event is supported, it requires filters for file patters (for example, `*.tf`).

#### Prerequisites

- AWS user with permission to create resources in the target account (for example, `AWS_TF_CBCI_EKS_AccessKeyID` and `AWS_TF_CBCI_EKS_SecretAccessKey`).
- AWS role to assume in the target account, including a trust relationship with the AWS user above.
- AWS Route 53 zone name, to create DNS records.

> [!IMPORTANT]
> CloudBees platform currently only supports push events. Therefore, pull requests are sent to the `develop` branch for integration.

## Release

CloudBees CI Terraform EKS Addon versions try to be in sync with the [CloudBees CI releases](https://docs.cloudbees.com/docs/release-notes/latest/cloudbees-ci/).

1. Ensure that `develop` branch follows its requisites from the [Design principles](#design-principles) section.
2. Test locally the (`develop`) for all the blueprints. Use the `test-all` target in the companion [Makefile](blueprints/Makefile).
3. Once all local tests passed successfully, create a PR against the `main` branch. It **must pass** the Center of Excellence (CoE) team validation.
4. Once the pull request is merged, update the `main` branch following its requisites from the [Design principles](#design-principles) section. The [Blueprint Terraform CI pipeline](#blueprint-terraform-ci-pipeline) must validate the changes.
5. Create a [new release](https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/releases). The release version semantics follow the Helm chart convention.

This project uses [Release Drafter](https://github.com/release-drafter/release-drafter); pull request labels should be set accordingly.

Kubernetes' environment versions are managed centrally in the [blueprints/.k8s.env](blueprints/.k8s.env) file.
