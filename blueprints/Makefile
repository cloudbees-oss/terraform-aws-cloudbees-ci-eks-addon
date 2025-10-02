.DEFAULT_GOAL   	:= help
SHELL           	:= /usr/bin/env bash
MAKEFLAGS       	+= --no-print-directory
MKFILEDIR 			:= $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
CBCI_REPO		    ?= https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon.git
CBCI_BRANCH			?= main
export DESTROY_WL_ONLY		?= false
export CI 					?= false

define helpers
	source $(MKFILEDIR)/helpers.sh && $(1)
endef

# if ROOT_DIR is not set, set it to current directory
ifndef ROOT_DIR
ROOT_DIR := $(MKFILEDIR)
endif

##########################
# Blueprint User
##########################

.PHONY: tfChecks
tfChecks: ## Run required terraform checks according to getting-started/README.md . Example: ROOT=02-at-scale make tfChecks
tfChecks: guard-ROOT
	@$(call helpers,$@)

.PHONY: agentCheck
agentCheck: ## Run agent check providing a warning message in case it is not used. Example:  make agentCheck
	@$(call helpers,$@)

.PHONY: bpAgent-dRun
bpAgent-dRun: ## Build (if not locally present) and Run the Blueprint Agent using Bash as Entrypoint. It is ideal starting point for all targets. Example: make bpAgent-dRun
	@$(call helpers,$@)

.PHONY: deploy
deploy: ## Deploy Terraform Blueprint passed as parameter. Example: ROOT=02-at-scale make deploy
deploy: tfChecks agentCheck
	@$(call helpers,$@)

.PHONY: validate
validate: ## Validate CloudBees CI Blueprint deployment passed as parameter. Example: ROOT=02-at-scale make validate
validate: tfChecks agentCheck
	@$(call helpers,$@)

.PHONY: destroy
destroy: ## Destroy Terraform Blueprint passed as parameter. Example: DESTROY_WL_ONLY=false ROOT=02-at-scale make destroy
destroy: tfChecks agentCheck guard-DESTROY_WL_ONLY
	@$(call helpers,$@)

.PHONY: clean
clean: ## Clean Blueprint passed as parameter. Example: ROOT=02-at-scale make clean
clean: guard-ROOT agentCheck
	@$(call helpers,$@)

##########################
# Blueprint Admin
##########################

.PHONY: test
test: ## Runs a test for blueprint passed as parameters throughout their Terraform Lifecycle. Example: ROOT=02-at-scale make test
test: clean deploy validate destroy
	@$(call helpers,INFO "Test target for $(ROOT) passed succesfully.")

.PHONY: test-all
test-all: ## Runs test for all blueprints throughout their Terraform Lifecycle. Example: make test-all
	@$(call helpers,$@)
	@$(call helpers,INFO "All Tests target passed succesfully.")

.PHONY: pre-commit
pre-commit: ## Run pre-commits in all files. It is a recommended step before sending PR. Example: make pre-commit
	pre-commit run --all-files
	@$(call helpers,INFO "End of pre-commits checks.")

.PHONY: set-kube-env
set-kube-env: ## Set K8s version according to file .k8.env. Example: make set-kube-env
set-kube-env: agentCheck
	@$(call helpers,set-kube-env)
	@$(call helpers,INFO "Setting Kube environment finished succesfully.")

.PHONY: zip-all-casc-bundles
zip-all-casc-bundles: ## Creates a zip file containing all cbci casc bundles from 02 At scale. Example: make zip-all-casc-bundles
zip-all-casc-bundles: agentCheck
	@$(call helpers,zip-all-casc-bundles)
	@$(call helpers,INFO "Zip casc bundles finished succesfully.")

##########################
# Global
##########################

.PHONY: help
help: ## Makefile Help Page
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[\/\%a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-21s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST) 2>/dev/null

.PHONY: guard-%
guard-%:
	@if [[ "${${*}}" == "" ]]; then printf "\033[0;31m[ERROR]\033[0m %s\n" "Environment variable $* not set."; exit 1; fi
