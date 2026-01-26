### Enhanced Makefile for AI Installer
### Version: 2.0 - Refactored with improved cache handling and CI support

#==============================================================================
# Color and Output Formatting
#==============================================================================
BORDER = echo "========================================"
INFO = echo "[INFO]"
WARN = echo "[WARN]"
ERROR = echo "[ERROR]"
SUCCESS = echo "[SUCCESS]"

#==============================================================================
# Version Management
#==============================================================================
ifneq (,$(wildcard ./VERSION))
	include ./VERSION
	export
endif

#==============================================================================
# Git and Repository Configuration
#==============================================================================
GIT_HOST ?= gitlab.apk-group.net
TOOLS_PATH ?= support/ai/ai-useful-tools.git
TOOLS_REPO_SSH ?= git@$(GIT_HOST):$(TOOLS_PATH)
TOOLS_REPO_HTTPS ?= https://$(GIT_HOST)/$(TOOLS_PATH)

ifdef CI_JOB_TOKEN
	TOOLS_REPO_CLONE_URL := https://gitlab-ci-token:$(CI_JOB_TOKEN)@$(GIT_HOST)/$(TOOLS_PATH)
endif

#==============================================================================
# Version Variables
#==============================================================================
default_version := $(AI_VERSION)
pipeline_commit_tag := $(or $(CI_COMMIT_TAG),$(default_version))
ai_version := $(pipeline_commit_tag)

#==============================================================================
# Directory Structure
#==============================================================================
CACHE_DIR := .cache
BUILD_DIR := build
ROLE_DIR := roles
CACHE_ROOT := $(HOME)/.cache/ai-installer
APT_CACHE_DIR := $(CACHE_ROOT)/apt

#==============================================================================
# External Dependencies
#==============================================================================
NEXUS_REPOSITORY_URL := https://repo.apk-group.net/repository/share-objects
ELASTICSEARCH_VERSION := 8.15.5
KIBANA_VERSION := 8.15.5
SMART_ANALYZER_AI_VERSION = 1.0.46
SMART_ANALYZER_QDRANT_VERSION = 1.14.1
SMART_ANALYZER_HAPROXY_VERSION = alpine
SMART_ANALYZER_VLLM_OPENAI_VERSION = latest
SMART_ANALYZER_TEXT_EMBEDDINGS_VERSION = 1.8
SOAR_PLATFORM_N8N_VERSION = latest
SOAR_PLATFORM_POSTGRES_VERSION = 16
SOAR_PLATFORM_REDIS_VERSION = 6-alpine
SOAR_PLATFORM_NGINX_VERSION = alpine
SOAR_PLATFORM_WEB_DRIVER_VERSION = with-selenoid
#==============================================================================
# Repository Builder Configuration
#==============================================================================
REPO_BUILDER_DIR := $(CACHE_DIR)/repo_builder
REPO_BUILDER_CONFIG := $(REPO_BUILDER_DIR)/local-cache.yml
REPO_BUILDER_EXEC := $(REPO_BUILDER_DIR)/package-builder
REPO_BUILDER_ARCHIVE := $(CACHE_DIR)/repo_builder.tar.gz

#==============================================================================
# Local Repository Configuration
#==============================================================================
APT_LOCAL_REPOSITORY_JSON_FILE := ./local_repository.json
APT_LOCAL_REPOSITORY_JSON_FILE_MD5 := $(shell md5sum $(APT_LOCAL_REPOSITORY_JSON_FILE) 2>/dev/null | cut -d' ' -f1)
APT_LOCAL_REPOSITORY_CACHE_PATH := $(APT_CACHE_DIR)/$(APT_LOCAL_REPOSITORY_JSON_FILE_MD5)
APT_LOCAL_REPOSITORY_TARBALL := $(APT_LOCAL_REPOSITORY_CACHE_PATH)/repo.tar.gz
APT_LOCAL_REPOSITORY_TARGET := $(ROLE_DIR)/deploy_apt_repository/files/repo.tar.gz

#==============================================================================
# Ansible Repository Configuration
#==============================================================================
APT_ANSIBLE_REPOSITORY_JSON_FILE := ./ansible.json
APT_ANSIBLE_REPOSITORY_JSON_FILE_MD5 := $(shell md5sum $(APT_ANSIBLE_REPOSITORY_JSON_FILE) 2>/dev/null | cut -d' ' -f1)
APT_ANSIBLE_REPOSITORY_CACHE_PATH := $(APT_CACHE_DIR)/$(APT_ANSIBLE_REPOSITORY_JSON_FILE_MD5)
APT_ANSIBLE_REPOSITORY_TARBALL := $(APT_ANSIBLE_REPOSITORY_CACHE_PATH)/localrepository.tar.gz
APT_ANSIBLE_REPOSITORY_TARGET := $(ROLE_DIR)/deploy_apt_repository/files/localrepository.tar.gz

#==============================================================================
# Package Configuration
#==============================================================================
PACKAGE_NAME := ai_$(ai_version)_$(shell date +%Y%m%d%H%M%S)
PACKAGE_FILE := $(BUILD_DIR)/$(PACKAGE_NAME).tar.gz
PACKAGE_MD5_FILE := $(PACKAGE_FILE).md5

#==============================================================================
# Docker Images Download & Packaging
#==============================================================================
ELASTIC_KIBANA_DIR := $(ROLE_DIR)/deploy_elastic_kibana/files
ELASTICSEARCH_TARBALL := $(ELASTIC_KIBANA_DIR)/elasticsearch.tar.gz
KIBANA_TARBALL := $(ELASTIC_KIBANA_DIR)/kibana.tar.gz

# Smart Analyzer
SMART_ANALYZER_DIR := $(ROLE_DIR)/deploy_smart_analyzer/files
SMART_ANALYZER_AI_TARBALL := $(SMART_ANALYZER_DIR)/smart-analyzer-ai.tar.gz
SMART_ANALYZER_QDRANT_TARBALL := $(SMART_ANALYZER_DIR)/qdrant.tar.gz
SMART_ANALYZER_HAPROXY_TARBALL := $(SMART_ANALYZER_DIR)/haproxy.tar.gz
SMART_ANALYZER_VLLM_OPENAI_TARBALL := $(SMART_ANALYZER_DIR)/vllm-openai.tar.gz
SMART_ANALYZER_TEXT_EMBEDDINGS_TARBALL := $(SMART_ANALYZER_DIR)/text-embeddings-inference.tar.gz

# SOAR Platform (restructured to match SMART_ANALYZER style)
SOAR_PLATFORM_DIR := $(ROLE_DIR)/deploy_soar_platform/files
SOAR_PLATFORM_N8N_TARBALL := $(SOAR_PLATFORM_DIR)/apksoar.tar.gz
SOAR_PLATFORM_POSTGRES_TARBALL := $(SOAR_PLATFORM_DIR)/postgres.tar.gz
SOAR_PLATFORM_REDIS_TARBALL := $(SOAR_PLATFORM_DIR)/redis.tar.gz
SOAR_PLATFORM_NGINX_TARBALL := $(SOAR_PLATFORM_DIR)/nginx.tar.gz
SOAR_PLATFORM_WEB_DRIVER_TARBALL := $(SOAR_PLATFORM_DIR)/web_driver.tar.gz

#==============================================================================
# Debug Mode (set DEBUG=1 for verbose output)
#==============================================================================
ifdef DEBUG
	SHELL := /bin/bash -x
	VERBOSE := -v
else
	VERBOSE :=
endif

#==============================================================================
# PHONY Targets Declaration
#==============================================================================
.PHONY: all build clean clean_all clean_cache \
    init download download_elastic_kibana \
    init_builder build_ansible_repo build_repo \
    update_version package generate_md5sum_file upload \
    validate_cache validate_dependencies help \
    debug_info force_rebuild

#==============================================================================
# Default Target
#==============================================================================
all: build

#==============================================================================
# Main Build Pipeline
#==============================================================================
build: clean update_version validate_dependencies package
	@$(SUCCESS) "Build completed successfully!"
	@$(INFO) "Package: $(PACKAGE_FILE)"

#==============================================================================
# Help Target
#==============================================================================
help:
	@$(BORDER)
	@echo "AI Installer Makefile - Available Targets:"
	@$(BORDER)
	@echo "  make build			  - Full build pipeline (default)"
	@echo "  make clean			  - Clean build and cache directories"
	@echo "  make clean_all		  - Clean everything including cached repositories"
	@echo "  make clean_cache		- Clean only the repository cache"
	@echo "  make download		   - Download Elasticsearch and Kibana"
	@echo "  make build_ansible_repo - Build Ansible repository"
	@echo "  make build_repo		 - Build local repository"
	@echo "  make package			- Create package tarball"
	@echo "  make upload			 - Upload package to repository"
	@echo "  make force_rebuild	  - Force rebuild without using cache"
	@echo "  make debug_info		 - Display configuration information"
	@echo "  make help			   - Display this help message"
	@$(BORDER)
	@echo "Environment Variables:"
	@echo "  DEBUG=1				 - Enable verbose output"
	@echo "  REPO_USERNAME		   - Repository username for downloads"
	@echo "  REPO_PASSWORD		   - Repository password for downloads"
	@$(BORDER)

#==============================================================================
# Debug Information
#==============================================================================
debug_info:
	@$(BORDER)
	@echo "Configuration Information:"
	@$(BORDER)
	@echo "AI Version: $(ai_version)"
	@echo "Package Name: $(PACKAGE_NAME)"
	@echo "Build Directory: $(BUILD_DIR)"
	@echo "Cache Directory: $(CACHE_DIR)"
	@echo "APT Cache Root: $(APT_CACHE_DIR)"
	@echo ""
	@echo "Local Repository:"
	@echo "  JSON File: $(APT_LOCAL_REPOSITORY_JSON_FILE)"
	@echo "  JSON MD5: $(APT_LOCAL_REPOSITORY_JSON_FILE_MD5)"
	@echo "  Cache Path: $(APT_LOCAL_REPOSITORY_CACHE_PATH)"
	@echo "  Tarball: $(APT_LOCAL_REPOSITORY_TARBALL)"
	@echo "  Target: $(APT_LOCAL_REPOSITORY_TARGET)"
	@echo ""
	@echo "Ansible Repository:"
	@echo "  JSON File: $(APT_ANSIBLE_REPOSITORY_JSON_FILE)"
	@echo "  JSON MD5: $(APT_ANSIBLE_REPOSITORY_JSON_FILE_MD5)"
	@echo "  Cache Path: $(APT_ANSIBLE_REPOSITORY_CACHE_PATH)"
	@echo "  Tarball: $(APT_ANSIBLE_REPOSITORY_TARBALL)"
	@echo "  Target: $(APT_ANSIBLE_REPOSITORY_TARGET)"
	@echo ""
	@echo "Elasticsearch Version: $(ELASTICSEARCH_VERSION)"
	@echo "Kibana Version: $(KIBANA_VERSION)"
	@$(BORDER)
	@echo "Cache Status:"
	@echo "  Local Repo Exists: $$(test -f '$(APT_LOCAL_REPOSITORY_TARBALL)' && echo 'YES' || echo 'NO')"
	@echo "  Ansible Repo Exists: $$(test -f '$(APT_ANSIBLE_REPOSITORY_TARBALL)' && echo 'YES' || echo 'NO')"
	@echo "  Elasticsearch Exists: $$(test -f '$(ELASTICSEARCH_TARBALL)' && echo 'YES' || echo 'NO')"
	@echo "  Kibana Exists: $$(test -f '$(KIBANA_TARBALL)' && echo 'YES' || echo 'NO')"
	@$(BORDER)

#==============================================================================
# Validation Targets
#==============================================================================
validate_dependencies:
	@$(BORDER)
	@$(INFO) "Validating dependencies..."
	@command -v tar >/dev/null 2>&1 || { $(ERROR) "tar is required but not installed"; exit 1; }
	@command -v pigz >/dev/null 2>&1 || { $(ERROR) "pigz is required but not installed"; exit 1; }
	@command -v md5sum >/dev/null 2>&1 || { $(ERROR) "md5sum is required but not installed"; exit 1; }
	@command -v curl >/dev/null 2>&1 || { $(ERROR) "curl is required but not installed"; exit 1; }
	@command -v skopeo >/dev/null 2>&1 || { $(ERROR) "skopeo is required but not installed"; exit 1; }
	@test -f $(APT_LOCAL_REPOSITORY_JSON_FILE) || { $(ERROR) "$(APT_LOCAL_REPOSITORY_JSON_FILE) not found"; exit 1; }
	@test -f $(APT_ANSIBLE_REPOSITORY_JSON_FILE) || { $(ERROR) "$(APT_ANSIBLE_REPOSITORY_JSON_FILE) not found"; exit 1; }
	@$(SUCCESS) "All dependencies validated"

validate_cache:
	@$(BORDER)
	@$(INFO) "Validating cache integrity..."
	@if [ -d "$(APT_LOCAL_REPOSITORY_CACHE_PATH)" ] && [ ! -f "$(APT_LOCAL_REPOSITORY_TARBALL)" ]; then \
		$(WARN) "Local repository cache directory exists but tarball is missing - cleaning..."; \
		rm -rf $(APT_LOCAL_REPOSITORY_CACHE_PATH); \
	fi
	@if [ -d "$(APT_ANSIBLE_REPOSITORY_CACHE_PATH)" ] && [ ! -f "$(APT_ANSIBLE_REPOSITORY_TARBALL)" ]; then \
		$(WARN) "Ansible repository cache directory exists but tarball is missing - cleaning..."; \
		rm -rf $(APT_ANSIBLE_REPOSITORY_CACHE_PATH); \
	fi
	@$(SUCCESS) "Cache validation complete"

#==============================================================================
# Initialization Targets
#==============================================================================
init:
	@$(BORDER)
	@$(INFO) "Initializing directories..."
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(CACHE_DIR)
	@mkdir -p $(APT_CACHE_DIR)
	@mkdir -p $(ELASTIC_KIBANA_DIR)
	@mkdir -p $(ROLE_DIR)/deploy_apt_repository/files
	@mkdir -p $(ROLE_DIR)/deploy_smart_analyzer/files
	@$(SUCCESS) "Directories initialized"

#==============================================================================
# Download Targets
#==============================================================================
# download: init	download_elastic_kibana download_smart_analyzer_images download_soar_platform_images
# download_Lshell_python_libraries
# ==============================================================================
# Elasticsearch & Kibana
# ==============================================================================
download_elastic_kibana:
	@$(BORDER)
	@$(INFO) "Downloading Elasticsearch and Kibana..."
	@$(MAKE) --no-print-directory download_elasticsearch
	@$(MAKE) --no-print-directory download_kibana
	@$(SUCCESS) "Elasticsearch and Kibana download completed"
download_elasticsearch:
	@if [ -f "$(ELASTICSEARCH_TARBALL)" ]; then \
		$(INFO) "Elasticsearch $(ELASTICSEARCH_VERSION) already exists - skipping"; \
	else \
		$(INFO) "Downloading Elasticsearch $(ELASTICSEARCH_VERSION)..."; \
		skopeo copy $(VERBOSE) \
			docker://registry.apk-group.net/automation/modules/elasticsearch:$(ELASTICSEARCH_VERSION) \
			docker-archive:$(ELASTICSEARCH_TARBALL) || \
		{ $(ERROR) "Failed to download Elasticsearch"; exit 1; }; \
		$(SUCCESS) "Elasticsearch downloaded successfully"; \
	fi
download_kibana:
	@if [ -f "$(KIBANA_TARBALL)" ]; then \
		$(INFO) "Kibana $(KIBANA_VERSION) already exists - skipping"; \
	else \
		$(INFO) "Downloading Kibana $(KIBANA_VERSION)..."; \
		skopeo copy $(VERBOSE) \
			docker://registry.apk-group.net/automation/modules/kibana:$(KIBANA_VERSION) \
			docker-archive:$(KIBANA_TARBALL) || \
		{ $(ERROR) "Failed to download Kibana"; exit 1; }; \
		$(SUCCESS) "Kibana downloaded successfully"; \
	fi
# ==============================================================================
# Lshell Python Libraries
# ==============================================================================
download_Lshell_python_libraries:
	@$(BORDER)
	@$(INFO) "Downloading required Python packages for Lshell..."
	mkdir -p $(CACHE_DIR)/Lshell $(ROLE_DIR)/setup_python_packages/files
	pip3 download limited-shell \
		--python-version 3.11 \
		--only-binary=:all: \
		-d $(CACHE_DIR)/Lshell
	cd $(CACHE_DIR)/Lshell && tar --use-compress-program=pigz -cf ../../$(ROLE_DIR)/setup_python_packages/files/Lshell.tar.gz *
# ==============================================================================
# Smart Analyzer Images
# ==============================================================================
download_smart_analyzer_images:
	@$(BORDER)
	@$(INFO) "Downloading Smart Analyzer images..."
	@$(MAKE) --no-print-directory download_smart_analyzer_ai
	@$(MAKE) --no-print-directory download_qdrant
	@$(MAKE) --no-print-directory download_haproxy
	@$(MAKE) --no-print-directory download_vllm_openai
	@$(MAKE) --no-print-directory download_text_embeddings_inference
	@$(SUCCESS) "Smart Analyzer images download completed"
download_smart_analyzer_ai:
	@if [ -f "$(SMART_ANALYZER_AI_TARBALL)" ]; then \
		$(INFO) "Smart Analyzer AI $(SMART_ANALYZER_AI_VERSION) already exists - skipping"; \
	else \
		$(INFO) "Downloading Smart Analyzer AI $(SMART_ANALYZER_AI_VERSION)..."; \
		skopeo copy $(VERBOSE) \
			docker://registry.apk-group.net/automation/modules/smart-analyzer-ai:$(SMART_ANALYZER_AI_VERSION) \
			docker-archive:$(SMART_ANALYZER_AI_TARBALL) || \
		{ $(ERROR) "Failed to download Smart Analyzer AI"; exit 1; }; \
		$(SUCCESS) "Smart Analyzer AI downloaded successfully"; \
	fi
download_qdrant:
	@if [ -f "$(SMART_ANALYZER_QDRANT_TARBALL)" ]; then \
		$(INFO) "Qdrant $(SMART_ANALYZER_QDRANT_VERSION) already exists - skipping"; \
	else \
		$(INFO) "Downloading Qdrant $(SMART_ANALYZER_QDRANT_VERSION)..."; \
		skopeo copy $(VERBOSE) \
			docker://registry.apk-group.net/automation/modules/qdrant:$(SMART_ANALYZER_QDRANT_VERSION) \
			docker-archive:$(SMART_ANALYZER_QDRANT_TARBALL) || \
		{ $(ERROR) "Failed to download Qdrant"; exit 1; }; \
		$(SUCCESS) "Qdrant downloaded successfully"; \
	fi
download_haproxy:
	@if [ -f "$(SMART_ANALYZER_HAPROXY_TARBALL)" ]; then \
		$(INFO) "HAProxy $(SMART_ANALYZER_HAPROXY_VERSION) already exists - skipping"; \
	else \
		$(INFO) "Downloading HAProxy $(SMART_ANALYZER_HAPROXY_VERSION)..."; \
		skopeo copy $(VERBOSE) \
			docker://registry.apk-group.net/automation/haproxy:$(SMART_ANALYZER_HAPROXY_VERSION) \
			docker-archive:$(SMART_ANALYZER_HAPROXY_TARBALL) || \
		{ $(ERROR) "Failed to download HAProxy"; exit 1; }; \
		$(SUCCESS) "HAProxy downloaded successfully"; \
	fi
download_vllm_openai:
	@if [ -f "$(SMART_ANALYZER_VLLM_OPENAI_TARBALL)" ]; then \
		$(INFO) "vLLM OpenAI $(SMART_ANALYZER_VLLM_OPENAI_VERSION) already exists - skipping"; \
	else \
		$(INFO) "Downloading vLLM OpenAI $(SMART_ANALYZER_VLLM_OPENAI_VERSION)..."; \
		skopeo copy $(VERBOSE) \
			docker://registry.apk-group.net/automation/vllm/vllm-openai:$(SMART_ANALYZER_VLLM_OPENAI_VERSION) \
			docker-archive:$(SMART_ANALYZER_VLLM_OPENAI_TARBALL) || \
		{ $(ERROR) "Failed to download vLLM OpenAI"; exit 1; }; \
		$(SUCCESS) "vLLM OpenAI downloaded successfully"; \
	fi
download_text_embeddings_inference:
	@if [ -f "$(SMART_ANALYZER_TEXT_EMBEDDINGS_TARBALL)" ]; then \
		$(INFO) "Text Embeddings Inference $(SMART_ANALYZER_TEXT_EMBEDDINGS_VERSION) already exists - skipping"; \
	else \
		$(INFO) "Downloading Text Embeddings Inference $(SMART_ANALYZER_TEXT_EMBEDDINGS_VERSION)..."; \
		skopeo copy $(VERBOSE) \
			docker://registry.apk-group.net/automation/modules/text-embeddings-inference:$(SMART_ANALYZER_TEXT_EMBEDDINGS_VERSION) \
			docker-archive:$(SMART_ANALYZER_TEXT_EMBEDDINGS_TARBALL) || \
		{ $(ERROR) "Failed to download Text Embeddings Inference"; exit 1; }; \
		$(SUCCESS) "Text Embeddings Inference downloaded successfully"; \
	fi
# ==============================================================================
# SOAR Platform Images (Updated to match SMART_ANALYZER style)
# ==============================================================================
download_soar_platform_images:
	@$(BORDER)
	@$(INFO) "Downloading SOAR Platform images..."
	@$(MAKE) --no-print-directory download_soar_n8n
	@$(MAKE) --no-print-directory download_soar_postgres
	@$(MAKE) --no-print-directory download_soar_redis
	@$(MAKE) --no-print-directory download_soar_nginx
	@$(MAKE) --no-print-directory download_soar_web_driver
	@$(SUCCESS) "SOAR Platform images download completed"
download_soar_n8n:
	@if [ -f "$(SOAR_PLATFORM_N8N_TARBALL)" ]; then \
		$(INFO) "n8n $(SOAR_PLATFORM_N8N_VERSION) already exists - skipping"; \
	else \
		$(INFO) "Downloading n8n $(SOAR_PLATFORM_N8N_VERSION)..."; \
		skopeo copy $(VERBOSE) \
			docker://registry.apk-group.net/automation/apksoar/apksoar:$(SOAR_PLATFORM_N8N_VERSION) \
			docker-archive:$(SOAR_PLATFORM_N8N_TARBALL) || \
		{ $(ERROR) "Failed to download n8n"; exit 1; }; \
		$(SUCCESS) "n8n downloaded successfully"; \
	fi
download_soar_postgres:
	@if [ -f "$(SOAR_PLATFORM_POSTGRES_TARBALL)" ]; then \
		$(INFO) "PostgreSQL $(SOAR_PLATFORM_POSTGRES_VERSION) already exists - skipping"; \
	else \
		$(INFO) "Downloading PostgreSQL $(SOAR_PLATFORM_POSTGRES_VERSION)..."; \
		skopeo copy $(VERBOSE) \
			docker://registry.apk-group.net/library/postgres:$(SOAR_PLATFORM_POSTGRES_VERSION) \
			docker-archive:$(SOAR_PLATFORM_POSTGRES_TARBALL) || \
		{ $(ERROR) "Failed to download PostgreSQL"; exit 1; }; \
		$(SUCCESS) "PostgreSQL downloaded successfully"; \
	fi
download_soar_redis:
	@if [ -f "$(SOAR_PLATFORM_REDIS_TARBALL)" ]; then \
		$(INFO) "Redis $(SOAR_PLATFORM_REDIS_VERSION) already exists - skipping"; \
	else \
		$(INFO) "Downloading Redis $(SOAR_PLATFORM_REDIS_VERSION)..."; \
		skopeo copy $(VERBOSE) \
			docker://registry.apk-group.net/library/redis:$(SOAR_PLATFORM_REDIS_VERSION) \
			docker-archive:$(SOAR_PLATFORM_REDIS_TARBALL) || \
		{ $(ERROR) "Failed to download Redis"; exit 1; }; \
		$(SUCCESS) "Redis downloaded successfully"; \
	fi
download_soar_nginx:
	@if [ -f "$(SOAR_PLATFORM_NGINX_TARBALL)" ]; then \
		$(INFO) "Nginx $(SOAR_PLATFORM_NGINX_VERSION) already exists - skipping"; \
	else \
		$(INFO) "Downloading Nginx $(SOAR_PLATFORM_NGINX_VERSION)..."; \
		skopeo copy $(VERBOSE) \
			docker://registry.apk-group.net/automation/nginx:$(SOAR_PLATFORM_NGINX_VERSION) \
			docker-archive:$(SOAR_PLATFORM_NGINX_TARBALL) || \
		{ $(ERROR) "Failed to download Nginx"; exit 1; }; \
		$(SUCCESS) "Nginx downloaded successfully"; \
	fi
download_soar_web_driver:
	@if [ -f "$(SOAR_PLATFORM_WEB_DRIVER_TARBALL)" ]; then \
		$(INFO) "Web Driver $(SOAR_PLATFORM_WEB_DRIVER_VERSION) already exists - skipping"; \
	else \
		$(INFO) "Downloading Web Driver $(SOAR_PLATFORM_WEB_DRIVER_VERSION)..."; \
		skopeo copy $(VERBOSE) \
			docker://registry.apk-group.net/automation/alpine-chrome:$(SOAR_PLATFORM_WEB_DRIVER_VERSION) \
			docker-archive:$(SOAR_PLATFORM_WEB_DRIVER_TARBALL) || \
		{ $(ERROR) "Failed to download Web Driver"; exit 1; }; \
		$(SUCCESS) "Web Driver downloaded successfully"; \
	fi
#==============================================================================
# Repository Builder Initialization
#==============================================================================
init_builder: init
	@$(BORDER)
	@$(INFO) "Initializing repository builder..."
	@if [ -x "$(REPO_BUILDER_EXEC)" ]; then \
		$(INFO) "Repository builder already initialized - skipping"; \
	else \
		$(INFO) "Downloading repository builder..."; \
		mkdir -p $(REPO_BUILDER_DIR); \
		curl -f -s -S -u $(REPO_USERNAME):$(REPO_PASSWORD) \
			-o $(REPO_BUILDER_ARCHIVE) \
			"$(NEXUS_REPOSITORY_URL)/repo_builder.tar.gz" || \
		{ $(ERROR) "Failed to download repository builder"; exit 1; }; \
		$(INFO) "Extracting repository builder..."; \
		tar --use-compress-program=pigz -xf $(REPO_BUILDER_ARCHIVE) -C $(CACHE_DIR) || \
		{ $(ERROR) "Failed to extract repository builder"; exit 1; }; \
		chmod +x $(REPO_BUILDER_EXEC); \
		$(SUCCESS) "Repository builder initialized"; \
	fi

#==============================================================================
# Ansible Repository Build
#==============================================================================
build_ansible_repo: init_builder validate_cache
	@$(BORDER)
	@$(INFO) "Building Ansible repository..."
	@$(INFO) "Cache path: $(APT_ANSIBLE_REPOSITORY_CACHE_PATH)"
	@$(INFO) "JSON MD5: $(APT_ANSIBLE_REPOSITORY_JSON_FILE_MD5)"
	@if [ -f "$(APT_ANSIBLE_REPOSITORY_TARBALL)" ]; then \
		$(INFO) "Ansible repository already exists in cache - reusing"; \
		$(INFO) "Using cached file: $(APT_ANSIBLE_REPOSITORY_TARBALL)"; \
	else \
		$(INFO) "Building new Ansible repository..."; \
		rm -rf $(APT_ANSIBLE_REPOSITORY_CACHE_PATH); \
		mkdir -p $(APT_ANSIBLE_REPOSITORY_CACHE_PATH); \
		$(INFO) "Configuring repository builder..."; \
		if [ -f "$(REPO_BUILDER_CONFIG).template" ]; then \
			cp $(REPO_BUILDER_CONFIG).template $(REPO_BUILDER_CONFIG); \
		else \
			echo "repository_path: /tmp/placeholder/" > $(REPO_BUILDER_CONFIG); \
			echo "nexus_base_url: $(NEXUS_REPOSITORY_URL)" >> $(REPO_BUILDER_CONFIG); \
			echo "nexus_username: $(REPO_USERNAME)" >> $(REPO_BUILDER_CONFIG); \
			echo "nexus_password: $(REPO_PASSWORD)" >> $(REPO_BUILDER_CONFIG); \
		fi; \
		sed -i "s@.*repository_path[[:space:]]*:.*@repository_path: $(APT_ANSIBLE_REPOSITORY_CACHE_PATH)/@g" $(REPO_BUILDER_CONFIG); \
		$(INFO) "Running package builder for Ansible repository..."; \
		$(REPO_BUILDER_EXEC) -c $(REPO_BUILDER_CONFIG) build -i $(APT_ANSIBLE_REPOSITORY_JSON_FILE) || \
		{ $(ERROR) "Package builder failed for Ansible repository"; exit 1; }; \
		$(INFO) "Verifying Ansible repository tarball..."; \
		TARBALL=$$(find $(APT_ANSIBLE_REPOSITORY_CACHE_PATH) -maxdepth 1 -name "*.tar.gz" -type f | head -n 1); \
		if [ -z "$$TARBALL" ]; then \
			$(ERROR) "Ansible repository tarball was not created"; \
			exit 1; \
		fi; \
		$(INFO) "Found tarball: $$(basename $$TARBALL)"; \
		mv "$$TARBALL" $(APT_ANSIBLE_REPOSITORY_TARBALL); \
		$(SUCCESS) "Ansible repository built successfully"; \
	fi
	@$(INFO) "Copying Ansible repository to role directory..."
	@mkdir -p $(dir $(APT_ANSIBLE_REPOSITORY_TARGET))
	@cp -f $(APT_ANSIBLE_REPOSITORY_TARBALL) $(APT_ANSIBLE_REPOSITORY_TARGET) || \
		{ $(ERROR) "Failed to copy Ansible repository tarball"; exit 1; }
	@$(SUCCESS) "Ansible repository ready at: $(APT_ANSIBLE_REPOSITORY_TARGET)"

#==============================================================================
# Local Repository Build
#==============================================================================
build_repo: init_builder validate_cache
	@$(BORDER)
	@$(INFO) "Building local repository..."
	@$(INFO) "Cache path: $(APT_LOCAL_REPOSITORY_CACHE_PATH)"
	@$(INFO) "JSON MD5: $(APT_LOCAL_REPOSITORY_JSON_FILE_MD5)"
	@if [ -f "$(APT_LOCAL_REPOSITORY_TARBALL)" ]; then \
		$(INFO) "Local repository already exists in cache - reusing"; \
		$(INFO) "Using cached file: $(APT_LOCAL_REPOSITORY_TARBALL)"; \
	else \
		$(INFO) "Building new local repository..."; \
		rm -rf $(APT_LOCAL_REPOSITORY_CACHE_PATH); \
		mkdir -p $(APT_LOCAL_REPOSITORY_CACHE_PATH); \
		$(INFO) "Configuring repository builder..."; \
		if [ -f "$(REPO_BUILDER_CONFIG).template" ]; then \
			cp $(REPO_BUILDER_CONFIG).template $(REPO_BUILDER_CONFIG); \
		else \
			echo "repository_path: /tmp/placeholder/" > $(REPO_BUILDER_CONFIG); \
			echo "nexus_base_url: $(NEXUS_REPOSITORY_URL)" >> $(REPO_BUILDER_CONFIG); \
			echo "nexus_username: $(REPO_USERNAME)" >> $(REPO_BUILDER_CONFIG); \
			echo "nexus_password: $(REPO_PASSWORD)" >> $(REPO_BUILDER_CONFIG); \
		fi; \
		sed -i "s@.*repository_path[[:space:]]*:.*@repository_path: $(APT_LOCAL_REPOSITORY_CACHE_PATH)/@g" $(REPO_BUILDER_CONFIG); \
		$(INFO) "Running package builder for local repository..."; \
		$(REPO_BUILDER_EXEC) -c $(REPO_BUILDER_CONFIG) build -i $(APT_LOCAL_REPOSITORY_JSON_FILE) || \
		{ $(ERROR) "Package builder failed for local repository"; exit 1; }; \
		$(INFO) "Verifying local repository tarball..."; \
		TARBALL=$$(find $(APT_LOCAL_REPOSITORY_CACHE_PATH) -maxdepth 1 -name "*.tar.gz" -type f | head -n 1); \
		if [ -z "$$TARBALL" ]; then \
			$(ERROR) "Local repository tarball was not created"; \
			exit 1; \
		fi; \
		$(INFO) "Found tarball: $$(basename $$TARBALL)"; \
		mv "$$TARBALL" $(APT_LOCAL_REPOSITORY_TARBALL); \
		$(SUCCESS) "Local repository built successfully"; \
	fi
	@$(INFO) "Copying local repository to role directory..."
	@mkdir -p $(dir $(APT_LOCAL_REPOSITORY_TARGET))
	@cp -f $(APT_LOCAL_REPOSITORY_TARBALL) $(APT_LOCAL_REPOSITORY_TARGET) || \
		{ $(ERROR) "Failed to copy local repository tarball"; exit 1; }
	@$(SUCCESS) "Local repository ready at: $(APT_LOCAL_REPOSITORY_TARGET)"

#==============================================================================
# Version Management
#==============================================================================
update_version:
	@$(BORDER)
	@$(INFO) "Current version: $(ai_version)"
	@if [ -z "$(ai_version)" ]; then \
		$(ERROR) "Version not set!"; \
		exit 1; \
	fi
	@$(SUCCESS) "Version validated"

#==============================================================================
# Packaging
#==============================================================================
package: download build_ansible_repo build_repo
	@$(BORDER)
	@$(INFO) "Creating tarball..."
	@tar --use-compress-program=pigz -cf $(PACKAGE_FILE) \
		$(ROLE_DIR) \
		install \
		inventory.yml \
		ansible.cfg \
		main-playbook.yml || \
		{ $(ERROR) "Failed to create package"; exit 1; }
	@$(SUCCESS) "Package created: $(PACKAGE_FILE)"
	@ls -lh $(PACKAGE_FILE)

generate_md5sum_file: package
	@$(BORDER)
	@$(INFO) "Generating MD5 checksum..."
	@test -f $(PACKAGE_FILE) || { $(ERROR) "Package file not found"; exit 1; }
	@md5sum $(PACKAGE_FILE) > $(PACKAGE_MD5_FILE)
	@$(SUCCESS) "MD5 checksum created: $(PACKAGE_MD5_FILE)"
	@cat $(PACKAGE_MD5_FILE)

#==============================================================================
# Upload
#==============================================================================
upload: generate_md5sum_file
	@$(BORDER)
	@$(INFO) "Uploading package (version: $(ai_version))..."
	@test -f ./upload.sh || { $(ERROR) "upload.sh script not found"; exit 1; }
	@chmod +x ./upload.sh
	@$(INFO) "Uploading package file..."
	@./upload.sh $(PACKAGE_FILE) siem-installer || \
		{ $(ERROR) "Failed to upload package"; exit 1; }
	@$(INFO) "Uploading MD5 file..."
	@./upload.sh $(PACKAGE_MD5_FILE) siem-installer || \
		{ $(ERROR) "Failed to upload MD5 file"; exit 1; }
	@$(SUCCESS) "Upload completed successfully"

#==============================================================================
# Cleaning Targets
#==============================================================================
clean:
	@$(BORDER)
	@$(INFO) "Cleaning build and cache directories..."
	@rm -rf $(BUILD_DIR)
	@rm -rf $(CACHE_DIR)
	@$(SUCCESS) "Clean completed"

clean_cache:
	@$(BORDER)
	@$(INFO) "Cleaning repository cache..."
	@rm -rf $(APT_LOCAL_REPOSITORY_CACHE_PATH)
	@rm -rf $(APT_ANSIBLE_REPOSITORY_CACHE_PATH)
	@$(SUCCESS) "Cache cleaned"

clean_all: clean clean_cache
	@$(BORDER)
	@$(INFO) "Cleaning all generated files..."
	@rm -rf $(ELASTIC_KIBANA_DIR)/*
	@rm -rf $(ROLE_DIR)/deploy_apt_repository/files/*.tar.gz
	@$(SUCCESS) "All files cleaned"

#==============================================================================
# Force Rebuild (ignores cache)
#==============================================================================
force_rebuild: clean_cache build
	@$(SUCCESS) "Force rebuild completed"

#==============================================================================
# End of Makefile
#==============================================================================
