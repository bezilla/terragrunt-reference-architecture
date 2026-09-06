# Reference-architecture task runner.
#
# Toolchain is pinned in mise.toml (run `mise install`). ENV selects the environment stack;
# override on the command line, e.g. `make plan ENV=staging`.

ENV ?= prod
ENVS      := staging prod
STACK_DIR := live/$(ENV)/us-west-2/$(ENV)
MGMT_DIR  := live/management/us-west-2/global

# Bootstrap is per ACCOUNT, not per environment: the state bucket is named for the account and
# region, so management/staging/prod each get exactly one regardless of how many environment
# stacks the account carries. ACCOUNT defaults to ENV because the workload accounts are named
# after their environment; management has to be asked for by name.
ACCOUNT  ?= $(ENV)
ACCOUNTS := management staging prod
BOOTSTRAP_DIR := live/$(ACCOUNT)/us-west-2/bootstrap/state-backend

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

.PHONY: fmt fmt-check validate validate-all lint test docs plan generate bootstrap bootstrap-plan lock scan clean help

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

# Bootstrap: once per account, by hand, before that account's stack is applied for the first time.
#
# Deliberately NOT part of `plan`/`apply`/`validate-all` and unreachable from any `run --all`: the
# unit lives outside every terragrunt.stack.hcl, so nothing that iterates a stack can plan, apply
# or destroy the bucket the rest of the account depends on.
#
# This is NOT a repeatable target on a fresh machine. Its state is a local terraform.tfstate in the
# unit directory, gitignored and never in CI; run it somewhere without that file and OpenTofu will
# try to create a bucket that already exists. Recovery is by import, not by re-run --
# see modules/state-backend/README.md and docs/adr/0011.
bootstrap-plan: ## Plan the state backend for ACCOUNT (defaults to ENV); requires AWS credentials
	cd $(BOOTSTRAP_DIR) && terragrunt plan

bootstrap: ## Apply the state backend for ACCOUNT (defaults to ENV); ONCE per account, local state
	cd $(BOOTSTRAP_DIR) && terragrunt apply

validate: ## Offline validate: management + ENV stacks, no AWS credentials required
	cd $(MGMT_DIR) && terragrunt stack generate && $(OFFLINE_VALIDATE)
	cd $(STACK_DIR) && terragrunt stack generate && $(OFFLINE_VALIDATE)

# What CI runs. `validate ENV=x` covers management plus ONE environment, which left prod --
# and with it the two units only prod declares (acm-certificate, cloudfront-waf) -- unvalidated
# on every push. This target is the one that makes "validate across all stacks" true.
# The bootstrap units are validated here too. They are excluded from every RUN path on purpose,
# which would otherwise leave them as the only configuration in the repo nothing ever checks --
# free to rot until the one moment someone needs them on a fresh account. Validating is read-only
# and needs no credentials; it applies nothing.
validate-all: ## Offline validate EVERY stack: management + all environments + the bootstrap units
	cd $(MGMT_DIR) && terragrunt stack generate && $(OFFLINE_VALIDATE)
	@for e in $(ENVS); do \
		echo "== live/$$e/us-west-2/$$e"; \
		( cd live/$$e/us-west-2/$$e && terragrunt stack generate && $(OFFLINE_VALIDATE) ) || exit 1; \
	done
	@for a in $(ACCOUNTS); do \
		echo "== live/$$a/us-west-2/bootstrap/state-backend"; \
		( cd live/$$a/us-west-2/bootstrap/state-backend && terragrunt run validate --non-interactive ) || exit 1; \
	done

# The platforms contributors and CI actually run on. `tofu init` locks only the platform it runs
# on, so a lockfile refreshed on a laptop stops verifying on the runner -- regenerate with this
# after bumping a provider constraint in a module's versions.tf, and commit the result.
PLATFORMS := darwin_arm64 darwin_amd64 linux_amd64

lock: ## Regenerate module lockfiles with hashes for every supported platform
	@for d in modules/*/; do \
		echo "== lock $$d"; \
		( cd $$d && tofu init -backend=false -input=false >/dev/null && \
		  tofu providers lock $(addprefix -platform=,$(PLATFORMS)) >/dev/null ) || exit 1; \
	done

lint: ## Run tflint across all modules
	@for d in modules/*/; do echo "== $$d"; (cd $$d && tflint) || exit 1; done

docs: ## Regenerate per-module READMEs with terraform-docs
	@for d in modules/*/; do terraform-docs markdown table --output-file README.md --output-mode inject $$d; done

plan: ## Plan the ENV stack (requires AWS credentials)
	cd $(STACK_DIR) && terragrunt stack generate && terragrunt run --all plan --non-interactive

test: ## Run module unit tests (tofu test) and policy tests (conftest)
	@mkdir -p $${TF_PLUGIN_CACHE_DIR:-$$HOME/.terraform.d/plugin-cache}
	@export TF_PLUGIN_CACHE_DIR=$${TF_PLUGIN_CACHE_DIR:-$$HOME/.terraform.d/plugin-cache}; \
	for d in modules/*/; do \
		echo "== test $$d"; \
		( cd $$d && tofu init -backend=false -input=false >/dev/null 2>&1 && tofu test ) || exit 1; \
	done
	conftest verify --policy policy

scan: ## Secret + origin-identifier scan (run from repo root; needs .gitleaks.local.toml)
	@test -f .gitleaks.local.toml || { echo "missing .gitleaks.local.toml (holds the origin-name rule; gitignored, local-only)"; exit 1; }
	gitleaks detect --source . --config .gitleaks.local.toml --no-banner --redact
	trufflehog filesystem . --no-update --results=verified,unknown

# Removes only generated trees. The bootstrap terraform.tfstate files under
# live/*/us-west-2/bootstrap/ are NOT generated and are deliberately left alone -- deleting one
# loses the record of that account's state bucket, recoverable then only by import.
clean: ## Remove generated stack + cache directories (never bootstrap state)
	find . -type d -name '.terragrunt-stack' -prune -exec rm -rf {} +
	find . -type d -name '.terragrunt-cache' -prune -exec rm -rf {} +
	find . -type d -name '.terraform' -prune -exec rm -rf {} +
