# Pulumix - Generate Nix modules from Pulumi schemas
.PHONY: help all clean aws azure gcp kubernetes docker install test

SHELL := /bin/bash
SCRIPT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
GENERATOR := $(SCRIPT_DIR)/generate.sh
SCHEMAS_DIR := $(SCRIPT_DIR)/schemas
OUTPUT_DIR := $(SCRIPT_DIR)/generated

# Default target
help: ## Show this help message
	@echo "Pulumix - Generate Nix modules from Pulumi schemas"
	@echo ""
	@echo "Usage:"
	@echo "  make <target>"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

all: aws azure gcp kubernetes ## Generate all major cloud provider modules

clean: ## Clean generated files and downloaded schemas
	@echo "Cleaning generated files and schemas..."
	rm -rf $(OUTPUT_DIR) $(SCHEMAS_DIR)
	@echo "✓ Cleaned"

# Individual cloud providers
aws: ## Generate AWS provider module
	@$(GENERATOR) aws

azure: ## Generate Azure provider module  
	@$(GENERATOR) azure

gcp: ## Generate Google Cloud provider module
	@$(GENERATOR) gcp

kubernetes: ## Generate Kubernetes provider module
	@$(GENERATOR) kubernetes

docker: ## Generate Docker provider module
	@$(GENERATOR) docker

# Utility providers
random: ## Generate Random provider module
	@$(GENERATOR) random

tls: ## Generate TLS provider module
	@$(GENERATOR) tls

local: ## Generate Local provider module
	@$(GENERATOR) local

# Development targets
install: ## Install dependencies and make scripts executable
	@echo "Setting up Pulumix..."
	@chmod +x $(SCRIPT_DIR)/generate.sh
	@chmod +x $(SCRIPT_DIR)/generator.py
	@echo "✓ Scripts are now executable"
	@echo "✓ Setup complete"

test: ## Run tests on generated modules
	@echo "Testing generated modules..."
	@if [ ! -d "$(OUTPUT_DIR)" ]; then \
		echo "No generated modules found. Run 'make aws' first."; \
		exit 1; \
	fi
	@for module in $(OUTPUT_DIR)/*.nix; do \
		echo "Testing $$module..."; \
		if nix-instantiate --parse "$$module" >/dev/null 2>&1; then \
			echo "✓ $$module is valid Nix"; \
		else \
			echo "✗ $$module has syntax errors"; \
			exit 1; \
		fi; \
	done
	@echo "✓ All modules are valid"

validate: test ## Alias for test

# Download schemas without generating
download-schemas: ## Download all provider schemas without generating modules
	@echo "Downloading provider schemas..."
	@$(GENERATOR) --download-only aws
	@$(GENERATOR) --download-only azure  
	@$(GENERATOR) --download-only gcp
	@$(GENERATOR) --download-only kubernetes
	@$(GENERATOR) --download-only docker
	@$(GENERATOR) --download-only random
	@$(GENERATOR) --download-only tls
	@$(GENERATOR) --download-only local
	@echo "✓ Downloaded all schemas"

# Generate from existing schemas
generate-all: ## Generate modules from all downloaded schemas
	@if [ ! -d "$(SCHEMAS_DIR)" ] || [ -z "$$(ls -A $(SCHEMAS_DIR) 2>/dev/null)" ]; then \
		echo "No schemas found. Run 'make download-schemas' first."; \
		exit 1; \
	fi
	@$(GENERATOR)

# Custom schema processing
generate-custom: ## Generate module from custom schema (usage: make generate-custom SCHEMA=path/to/schema.json)
ifndef SCHEMA
	@echo "Usage: make generate-custom SCHEMA=path/to/schema.json"
	@exit 1
endif
	@$(GENERATOR) -s $(SCHEMA)

# Generate without formatting (for debugging)
aws-compact: ## Generate AWS module without alejandra formatting
	@NO_FORMAT=1 $(GENERATOR) aws

# Format all existing modules
format: ## Format all generated modules with alejandra
	@if command -v alejandra >/dev/null 2>&1; then \
		echo "Formatting all generated modules..."; \
		find $(OUTPUT_DIR) -name "*.nix" -exec alejandra {} \; 2>/dev/null || true; \
		echo "✓ Formatting complete"; \
	else \
		echo "alejandra not found - install with: nix profile install nixpkgs#alejandra"; \
		exit 1; \
	fi

show-schemas: ## List all downloaded schemas
	@echo "Downloaded schemas:"
	@if [ -d "$(SCHEMAS_DIR)" ]; then \
		ls -la $(SCHEMAS_DIR)/*.json 2>/dev/null || echo "No schemas found"; \
	else \
		echo "Schemas directory does not exist"; \
	fi

show-modules: ## List all generated modules
	@echo "Generated modules:"
	@if [ -d "$(OUTPUT_DIR)" ]; then \
		ls -la $(OUTPUT_DIR)/*.nix 2>/dev/null || echo "No modules found"; \
	else \
		echo "Output directory does not exist"; \
	fi

# Package and distribution
package: all ## Create a distributable package with all modules
	@echo "Creating distributable package..."
	@mkdir -p dist/pulumix
	@cp -r $(OUTPUT_DIR)/* dist/pulumix/ 2>/dev/null || true
	@cp README.md dist/pulumix/ 2>/dev/null || echo "# Pulumix Generated Modules" > dist/pulumix/README.md
	@echo "{ pkgs ? import <nixpkgs> {} }: {" > dist/pulumix/default.nix
	@for module in $(OUTPUT_DIR)/*.nix; do \
		name=$$(basename "$$module" .nix); \
		echo "  $$name = import ./$$name.nix;" >> dist/pulumix/default.nix; \
	done 2>/dev/null || true
	@echo "}" >> dist/pulumix/default.nix
	@tar -czf dist/pulumix.tar.gz -C dist pulumix
	@echo "✓ Package created: dist/pulumix.tar.gz"

# Version and info targets
version: ## Show version information
	@echo "Pulumix Schema Generator"
	@echo "Python: $$(python3 --version 2>&1)"
	@echo "Bash: $$BASH_VERSION"
	@if command -v nix >/dev/null 2>&1; then \
		echo "Nix: $$(nix --version)"; \
	else \
		echo "Nix: not installed"; \
	fi

check-deps: ## Check if all dependencies are available
	@echo "Checking dependencies..."
	@command -v python3 >/dev/null 2>&1 || (echo "✗ python3 not found" && exit 1)
	@command -v curl >/dev/null 2>&1 || (echo "✗ curl not found" && exit 1)
	@command -v jq >/dev/null 2>&1 || echo "⚠ jq not found (optional, for JSON processing)"
	@command -v nix >/dev/null 2>&1 || echo "⚠ nix not found (needed for validation)"
	@command -v alejandra >/dev/null 2>&1 || echo "⚠ alejandra not found (install with: nix profile install nixpkgs#alejandra)"
	@echo "✓ Dependencies check complete"

# Help is the default target
.DEFAULT_GOAL := help
