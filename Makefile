### Colors Vars
BORDER= echo "----------------------------------------"
###
.PHONY: update_version build download build_repo clean clean_all init_builder package clone_check_script
ifneq (,$(wildcard ./VERSION))
    include ./VERSION
    export
endif
GIT_HOST ?= gitlab.apk-group.net
TOOLS_PATH ?= support/ai/ai-useful-tools.git
TOOLS_REPO_SSH ?= git@$(GIT_HOST):$(TOOLS_PATH)
TOOLS_REPO_HTTPS ?= https://$(GIT_HOST)/$(TOOLS_PATH)
TOOLS_REPO_HTTPS ?= https://$(GIT_HOST)/$(TOOLS_PATH)
ifdef CI_JOB_TOKEN
TOOLS_REPO_CLONE_URL := https://gitlab-ci-token:$(CI_JOB_TOKEN)@$(GIT_HOST)/$(TOOLS_PATH)
endif
default_version:=$(AI_VERSION)
pipeline_commit_tag:=$(or $(CI_COMMIT_TAG),$(default_version))
ai_version:=$(pipeline_commit_tag)
CACHE_DIR:=.cache
BUILD_DIR:=build
ROLE_DIR:=roles
NEXUS_REPOSITORY_URL:=https://repo.apk-group.net/repository/share-objects
REPO_BUILDER_CONFIG := $(CACHE_DIR)/repo_builder/local-cache.yml

APT_LOCAL_REPOSITORY_JSON_FILE := ./local_repository.json
APT_LOCAL_REPOSITORY_JSON_FILE_MD5 := $(shell md5sum $(APT_LOCAL_REPOSITORY_JSON_FILE) | cut -d' ' -f1)
APT_LOCAL_REPOSITORY_CACHE_PATH := $(HOME)/.cache/ai-installer/apt/$(APT_LOCAL_REPOSITORY_JSON_FILE_MD5)

APT_ANSIBLE_REPOSITORY_JSON_FILE := ./ansible.json
APT_ANSIBLE_REPOSITORY_JSON_FILE_MD5 := $(shell md5sum $(APT_ANSIBLE_REPOSITORY_JSON_FILE) | cut -d' ' -f1)
APT_ANSIBLE_REPOSITORY_CACHE_PATH := $(HOME)/.cache/ai-installer/apt/$(APT_ANSIBLE_REPOSITORY_JSON_FILE_MD5)

ELASTICSEARCH_VERSION=8.15.5
KIBANA_VERSION=8.15.5

PACKAGE_NAME := ai_$(ai_version)_$(shell date +%Y%m%d%H)

build:  clean clean_all update_version download build_repo package upload

init:
	@$(BORDER)
	@echo "Initializing directories..."
	mkdir -p $(BUILD_DIR) $(CACHE_DIR)

download: init download_elastic_kibana

download_elastic_kibana:
	@echo "Downloading Elasticsearch $(ELASTICSEARCH_VERSION)..."
	@mkdir -p roles/deploy_elastic_kibana/files
	@if [ ! -f roles/deploy_elastic_kibana/files/elasticsearch.tar.gz ]; then \
		echo "Downloading Elasticsearch..."; \
		skopeo copy docker://registry.apk-group.net/automation/modules/elasticsearch:$(ELASTICSEARCH_VERSION) \
			docker-archive:roles/deploy_elastic_kibana/files/elasticsearch.tar.gz || \
		{ echo "Failed to download Elasticsearch"; exit 1; }; \
		echo "Elasticsearch downloaded."; \
	else \
		echo "Elasticsearch already exists. Skipping."; \
	fi

	@echo "Downloading Kibana $(KIBANA_VERSION)..."
	@if [ ! -f roles/deploy_elastic_kibana/files/kibana.tar.gz ]; then \
		echo "Downloading Kibana..."; \
		skopeo copy docker://registry.apk-group.net/automation/modules/kibana:$(KIBANA_VERSION) \
			docker-archive:roles/deploy_elastic_kibana/files/kibana.tar.gz || \
		{ echo "Failed to download Kibana (maybe tag doesn't exist?)"; exit 1; }; \
		echo "Kibana downloaded."; \
	else \
		echo "Kibana already exists. Skipping."; \
	fi

	@echo "Download completed."

# download_Lshell_python_libraries:
# 	@$(BORDER)
# 	@echo "Downloading require python packages for Lshell"
# 	mkdir -p $(CACHE_DIR)/Lshell $(ROLE_DIR)/setup_python_packages/files
# 	pip3 download limited-shell  --python-version 3.11 --only-binary=:all: -d $(CACHE_DIR)/Lshell
# 	cd $(CACHE_DIR)/Lshell && tar --use-compress-program=pigz -cf ../../$(ROLE_DIR)/setup_python_packages/files/Lshell.tar.gz *

# download_esrally:
# 	@$(BORDER)
# 	@echo "Downloading require python packages for esrally"
# 	mkdir -p $(CACHE_DIR)/esrally $(ROLE_DIR)/setup_python_packages/files
# 	pip3 download esrally -d $(CACHE_DIR)/esrally
# 	cd $(CACHE_DIR)/esrally && tar --use-compress-program=pigz -cf ../../$(ROLE_DIR)/setup_python_packages/files/esrally.tar.gz *


init_builder:
	@$(BORDER)
	@echo "Initializing builder environment..."
	mkdir -p $(BUILD_DIR) $(CACHE_DIR)/repo_builder
	curl -f -u $(REPO_USERNAME):$(REPO_PASSWORD) -o $(CACHE_DIR)/repo_builder.tar.gz "$(NEXUS_REPOSITORY_URL)/repo_builder.tar.gz"
	tar --use-compress-program=pigz -xf $(CACHE_DIR)/repo_builder.tar.gz -C $(CACHE_DIR)
	chmod +x $(CACHE_DIR)/repo_builder/package-builder

build_ansible_repo: init_builder
	@$(BORDER)
	@echo "Building ansible repository..."
	@if [ -d "$(APT_ANSIBLE_REPOSITORY_CACHE_PATH)" ]; then \
		echo "Skip build $(APT_ANSIBLE_REPOSITORY_JSON_FILE). Repository Already exists"; \
	else \
		sed -i "s@.*repository_path[[:space:]]*:.*@repository_path: $(APT_ANSIBLE_REPOSITORY_CACHE_PATH)/@g" $(REPO_BUILDER_CONFIG); \
		rm -rf $(APT_ANSIBLE_REPOSITORY_CACHE_PATH)/ansible-depends $(APT_ANSIBLE_REPOSITORY_CACHE_PATH)/*.tar.gz $(APT_ANSIBLE_REPOSITORY_CACHE_PATH)/source; \
		mkdir -p $(APT_ANSIBLE_REPOSITORY_CACHE_PATH)/ansible-depends $(APT_ANSIBLE_REPOSITORY_CACHE_PATH)/source; \
		.cache/repo_builder/package-builder -c $(REPO_BUILDER_CONFIG) build -i $(APT_ANSIBLE_REPOSITORY_JSON_FILE); \
		tar --use-compress-program=pigz -xf $(APT_ANSIBLE_REPOSITORY_CACHE_PATH)/*.tar.gz -C $(APT_ANSIBLE_REPOSITORY_CACHE_PATH)/ansible-depends; \
		find $(APT_ANSIBLE_REPOSITORY_CACHE_PATH)/ansible-depends -name "*.deb" -exec mv {} $(APT_ANSIBLE_REPOSITORY_CACHE_PATH)/source \;; \
	fi

	tar --use-compress-program=pigz -cf $(ROLE_DIR)/deploy_apt_repository/files/localrepository.tar.gz -C $(APT_ANSIBLE_REPOSITORY_CACHE_PATH) source

build_repo: init_builder
	@$(BORDER)
	@echo "Building local repository..."
	@if [ -d "$(APT_LOCAL_REPOSITORY_CACHE_PATH)" ]; then \
		echo "Skip build $(APT_LOCAL_REPOSITORY_JSON_FILE). Repository Already exists"; \
	else \
		sed -i "s@.*repository_path[[:space:]]*:.*@repository_path: $(APT_LOCAL_REPOSITORY_CACHE_PATH)/@g" $(REPO_BUILDER_CONFIG); \
		cat $(REPO_BUILDER_CONFIG); \
		test -f $(APT_LOCAL_REPOSITORY_JSON_FILE) || { echo "Error: $(APT_LOCAL_REPOSITORY_JSON_FILE) not found"; exit 1; }; \
		.cache/repo_builder/package-builder -c $(REPO_BUILDER_CONFIG) build -i $(APT_LOCAL_REPOSITORY_JSON_FILE) || { echo "package-builder failed"; exit 1; }; \
	fi
	@test -f $(APT_LOCAL_REPOSITORY_CACHE_PATH)/*.tar.gz || { echo "Error: No tar.gz found in cache"; exit 1; }
	cp -rf $(APT_LOCAL_REPOSITORY_CACHE_PATH)/*.tar.gz $(ROLE_DIR)/deploy_apt_repository/files/repo.tar.gz

update_version:
	@$(BORDER)
	@echo "Updating version to $(ai_version)..."


clean:
	@$(BORDER)
	@echo "Cleaning build and cache..."
	rm -rf $(BUILD_DIR) $(CACHE_DIR)

clean_all: clean
	@$(BORDER)
	@echo "Cleaning all target files..."
#	@rm -rf $(ROLE_DIR)/deploy_elastic_kibana/files/* \

	@rm -rf $(APT_LOCAL_REPOSITORY_CACHE_PATH)
	@rm -rf $(APT_ANSIBLE_REPOSITORY_CACHE_PATH)

package:
	@$(BORDER)
	@echo "Packaging AI version $(ai_version)..."
	tar --use-compress-program=pigz -cf $(BUILD_DIR)/$(PACKAGE_NAME).tar.gz $(ROLE_DIR) install inventory.yml ansible.cfg main-playbook.yml
generate_md5sum_file:
	@$(BORDER)
	@echo "Generating md5 sum file..."
	md5sum $(BUILD_DIR)/$(PACKAGE_NAME).tar.gz > $(BUILD_DIR)/$(PACKAGE_NAME).tar.gz.md5
upload: generate_md5sum_file
	@$(BORDER)
	@echo "uploading AI version $(ai_version)..."
	./upload.sh $(BUILD_DIR)/$(PACKAGE_NAME).tar.gz siem-installer
	./upload.sh $(BUILD_DIR)/$(PACKAGE_NAME).tar.gz.md5 siem-installer

