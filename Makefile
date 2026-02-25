.PHONY: setup build deploy deploy-collection deploy-index destroy login validate fmt clean

# ── Initial Setup (install Python dependencies) ─────────────────
setup:
	pip3 install -r infra/modules/opensearch/scripts/requirements.txt
	@echo "Setup complete! Next: make build && make deploy"

# ── Build Lambda zip ─────────────────────────────────────────────
build:
	rm -rf ingestion/embed_lambda/package
	pip3 install -r ingestion/embed_lambda/requirements.txt \
		-t ingestion/embed_lambda/package --quiet
	cd ingestion/embed_lambda/package && \
		zip -r ../embed_lambda.zip . -x "*.pyc" -x "__pycache__/*"
	cd ingestion/embed_lambda && zip -g embed_lambda.zip handler.py
	mv ingestion/embed_lambda/embed_lambda.zip ingestion/embed_lambda.zip
	@echo "Lambda zip ready: ingestion/embed_lambda.zip"

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
	rm -rf ingestion/embed_lambda/package
	rm -f  ingestion/embed_lambda.zip
	@echo "Local cache cleaned"
