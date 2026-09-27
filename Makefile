# local kind workflows

ENV ?= dev
IMAGE ?= assignment-web
TAG ?= local
TFDIR = infra/environments/$(ENV)

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

.PHONY: test
test: ## Run app unit tests
	cd app && pip install -q -r requirements.txt pytest && pytest -q

.PHONY: build
build: ## Build the app image
	docker build -t $(IMAGE):$(TAG) app

.PHONY: up
up: ## Provision the cluster + addons for ENV (default: dev)
	cd $(TFDIR) && terraform init && terraform apply -auto-approve

.PHONY: load
load: build ## Load the locally-built image into the kind cluster
	kind load docker-image $(IMAGE):$(TAG) --name assignment-$(ENV)

.PHONY: deploy
deploy: ## Deploy the app overlay for ENV, pinned to the local image
	cd deploy/overlays/$(ENV) && \
		kubectl kustomize . | \
		sed 's#ghcr.io/OWNER/assignment-web:$(ENV)#$(IMAGE):$(TAG)#' | \
		kubectl apply -f -
	kubectl -n web-$(ENV) rollout status deploy/$(ENV)-web --timeout=120s

.PHONY: smoke
smoke: ## Curl the app through the ingress
	curl -fsS -H "Host: web.$(ENV).localtest.me" http://localhost/ && echo

.PHONY: all
all: up load deploy smoke ## Full path: cluster -> image -> deploy -> verify

.PHONY: down
down: ## Destroy the ENV cluster
	cd $(TFDIR) && terraform destroy -auto-approve
