# Reference-architecture task runner.
#
# Toolchain is pinned in mise.toml (run `mise install`). ENV selects the environment stack;
# override on the command line, e.g. `make plan ENV=staging`.

ENV ?= prod
STACK_DIR := live/$(ENV)/us-west-2/$(ENV)
MGMT_DIR  := live/management/us-west-2/global

# The offline-validation gate.
#
# `tofu init` for an S3 backend needs AWS credentials, so a plain `terragrunt run --all validate`
# cannot run on a credential-less clean clone. This target:
#   - TG_DISABLE_BACKEND=true      -> root.hcl injects `-backend=false` into init (offline)
#   - --no-dependency-outputs      -> use each dependency's mock_outputs instead of real state
#   - --experiment optional-dependency-outputs  -> enables the flag above
# NOTE: `optional-dependency-outputs` is an EXPERIMENTAL Terragrunt flag. It was verified against
# the exact terragrunt/tofu versions pinned in mise.toml; a Terragrunt upgrade may rename or
# graduate it. If this target breaks after a bump, check `terragrunt run --help` for the flag.
OFFLINE_VALIDATE = TG_DISABLE_BACKEND=true terragrunt run --all validate \
	--non-interactive --no-dependency-outputs --experiment optional-dependency-outputs

.PHONY: fmt fmt-check validate lint docs plan generate clean help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  %-14s %s\n", $$1, $$2}'

fmt: ## Format all HCL and OpenTofu files
	terragrunt hcl fmt
	tofu fmt -recursive modules

fmt-check: ## Check formatting (CI)
	terragrunt hcl fmt --check --diff
	tofu fmt -recursive -check modules

generate: ## Generate the stack for ENV (default prod)
	cd $(STACK_DIR) && terragrunt stack generate

validate: ## Offline validate: management + ENV stacks, no AWS credentials required
	cd $(MGMT_DIR) && terragrunt stack generate && $(OFFLINE_VALIDATE)
	cd $(STACK_DIR) && terragrunt stack generate && $(OFFLINE_VALIDATE)

lint: ## Run tflint across all modules
	@for d in modules/*/; do echo "== $$d"; (cd $$d && tflint) || exit 1; done

docs: ## Regenerate per-module READMEs with terraform-docs
	@for d in modules/*/; do terraform-docs markdown table --output-file README.md --output-mode inject $$d; done

plan: ## Plan the ENV stack (requires AWS credentials)
	cd $(STACK_DIR) && terragrunt stack generate && terragrunt run --all plan --non-interactive

clean: ## Remove generated stack + cache directories
	find . -type d -name '.terragrunt-stack' -prune -exec rm -rf {} +
	find . -type d -name '.terragrunt-cache' -prune -exec rm -rf {} +
	find . -type d -name '.terraform' -prune -exec rm -rf {} +
