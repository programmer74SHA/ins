### Colors Vars
COLOR_GREEN=\033[1;32m
COLOR_YELLOW=\033[1;33m
COLOR_PURPLE=\033[1;35m
END_COLOR=\033[0m
BORDER= echo "$(COLOR_PURPLE)----------------------------------------$(END_COLOR)"
###
.PHONY: update_version build download build_repo clean clean_all init_builder package

ifneq (,$(wildcard ./VERSION))
	include ./VERSION
	export
endif

default_version:=$(AI_VERSION)
pipeline_commit_tag:=$(or $(CI_COMMIT_TAG),$(default_version))
AI_version:=$(pipeline_commit_tag)
CACHE_DIR:=.cache
BUILD_DIR:=build
ROLE_DIR:=roles
DOWNLOAD_DIR:=$(ROLE_DIR)/download
KIBANA_VERSION=8.15.5
ElasticSEARCH_VERSION=8.15.5

build: download build_repo package upload

download: download_elastic_kibana

download_elastic_kibana:
	@echo "══════════════════════════════════════════════════"
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

	@echo "══════════════════════════════════════════════════"
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

	@echo "══════════════════════════════════════════════════"
	@echo "Download completed."


build_repo: init_builder
	@echo "$(COLOR_GREEN)Building repository...$(END_COLOR)"


init_builder:
	@echo "$(COLOR_GREEN)Initializing builder environment...$(END_COLOR)"

update_version:
	@echo "$(COLOR_YELLOW)Updating version to $(AI_version)...$(END_COLOR)"

init:
	@$(BORDER)
	@echo "$(COLOR_GREEN)Initializing directories...$(END_COLOR)"
	mkdir -p $(BUILD_DIR) $(CACHE_DIR)

clean:
	@$(BORDER)
	@echo "$(COLOR_GREEN)Cleaning build and cache...$(END_COLOR)"
	rm -rf $(BUILD_DIR) $(CACHE_DIR)

clean_all: clean
	@echo "$(COLOR_YELLOW)Performing deep clean (cache and build directories)...$(END_COLOR)"

package:
	@$(BORDER)
	@echo "$(COLOR_GREEN)Packaging AI version $(COLOR_YELLOW)$(AI_version)$(END_COLOR)...$(END_COLOR)"
	tar --use-compress-program=pigz -cf $(BUILD_DIR)/ai_$(ai_version)_$(shell date +%Y%m%d%H).tar.gz $(ROLE_DIR) install inventory.yml ansible.cfg main-playbook.yml

generate_md5sum_file:
	@$(BORDER)
	@echo "$(COLOR_GREEN)Generating md5 sum file...$(END_COLOR)"
	md5sum $(BUILD_DIR)/ai_$(ai_version)_$(shell date +%Y%m%d%H).tar.gz > $(BUILD_DIR)/ai_$(ai_version)_$(shell date +%Y%m%d%H).tar.gz.md5

upload: generate_md5sum_file
	@$(BORDER)
	@echo "$(COLOR_GREEN)uploading AI version $(COLOR_YELLOW)$(ai_version)$(END_COLOR)...$(END_COLOR)"
	./upload.sh $(BUILD_DIR)/ai_$(ai_version)_$(shell date +%Y%m%d%H).tar.gz ai-installer
	./upload.sh $(BUILD_DIR)/ai_$(ai_version)_$(shell date +%Y%m%d%H).tar.gz.md5 ai-installer
