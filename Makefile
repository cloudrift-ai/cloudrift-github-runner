.PHONY: setup test lint fmt deploy deploy-init deploy-destroy clean

SOURCE_ZIP := /tmp/cloudrift-runner-source.zip
SOURCE_HASH := $(shell cd $(CURDIR) && find src/ pyproject.toml -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)
TF_DIR := deploy/terraform

setup:
	python3 -m venv .venv
	.venv/bin/pip install -e ".[dev]"
	@if ! command -v terraform >/dev/null 2>&1; then \
		echo "Terraform not found, installing..."; \
		if command -v apt-get >/dev/null 2>&1; then \
			sudo apt-get update && sudo apt-get install -y gnupg software-properties-common && \
			wget -qO- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
			echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $$(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list && \
			sudo apt-get update && sudo apt-get install -y terraform; \
		elif command -v brew >/dev/null 2>&1; then \
			brew tap hashicorp/tap && brew install hashicorp/tap/terraform; \
		else \
			echo "ERROR: Could not install Terraform. Install it manually: https://developer.hashicorp.com/terraform/install"; \
			exit 1; \
		fi; \
	else \
		echo "Terraform already installed: $$(terraform version -json | head -1)"; \
	fi
	@if [ ! -d "$(TF_DIR)/.terraform" ]; then \
		echo "Running terraform init..."; \
		cd $(TF_DIR) && terraform init; \
	fi

test:
	.venv/bin/pytest -vv

lint:
	.venv/bin/ruff check src/ tests/
	.venv/bin/ruff format --check src/ tests/

fmt:
	.venv/bin/ruff format src/ tests/
	.venv/bin/ruff check --fix src/ tests/

$(SOURCE_ZIP): src/ pyproject.toml
	cd $(CURDIR) && zip -r $(SOURCE_ZIP) src/ pyproject.toml

deploy-init:
	cd $(TF_DIR) && terraform init

deploy: $(SOURCE_ZIP)
	cd $(TF_DIR) && terraform apply \
		-var="source_zip_path=$(SOURCE_ZIP)" \
		-var="source_hash=$(SOURCE_HASH)"

deploy-destroy:
	cd $(TF_DIR) && terraform destroy

clean:
	rm -f $(SOURCE_ZIP)
