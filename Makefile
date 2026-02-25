.PHONY: setup deploy deploy-collection deploy-index destroy login validate fmt clean

# ── Initial Setup (install Python dependencies) ─────────────────
setup:
	pip3 install -r infra/modules/opensearch/scripts/requirements.txt
	@echo "Setup complete! Next: make deploy"

# ── AWS SSO Login (only needed on local, skip on SageMaker) ─────
login:
	aws sso login --profile ut-oxy-capstone
	@echo "AWS login complete"

# ── Deploy (2-pass, runs automatically) ─────────────────────────
deploy: deploy-collection deploy-index
	@echo "Full deployment complete!"

deploy-collection:
	cd infra && terraform init && \
	terraform apply -var="create_index=false" -auto-approve

deploy-index:
	cd infra && terraform apply -var="create_index=true" -auto-approve

# ── Teardown ─────────────────────────────────────────────────────
destroy:
	cd infra && terraform destroy
	@echo "All resources destroyed — billing stopped"

# ── Validation ───────────────────────────────────────────────────
validate:
	cd infra && terraform fmt -check -recursive && terraform validate

fmt:
	cd infra && terraform fmt -recursive

# ── Local Cleanup ────────────────────────────────────────────────
clean:
	rm -rf infra/.terraform
	@echo "Local cache cleaned"
