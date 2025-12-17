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

download_elastic_search:
	@$BORDER
	@echo "$(COLOR_GREEN)Downloading Elastic Search...$(END_COLOR)"
	@mkdir -p roles/deploy_elastic_kibana/files
	@if [ ! -f roles/deploy_elastic_kibana/files/elasticsearch.tar.gz ]; then \
		skopeo copy docker://registry.apk-group.net/automation/modules/elasticsearch:$(ELASTICSEARCH_VERSION) docker-archive:roles/deploy_elastic_kibana/files/elasticsearch.tar.gz; \
	fi
	@$BORDER
	@echo "$(COLOR_GREEN)Downloading Kibana...$(END_COLOR)"
	@mkdir -p roles/deploy_elastic_kibana/files
	@if [ ! -f roles/deploy_elastic_kibana/files/kibana.tar.gz ]; then \
		skopeo copy docker://registry.apk-group.net/automation/modules/kibana:$(KIBANA_VERSION) docker-archive:roles/deploy_elastic_kibana/files/kibana.tar.gz; \
	fi

build_repo: init_builder
	@echo "$(COLOR_GREEN)Building repository...$(END_COLOR)"


init_builder:
	@echo "$(COLOR_GREEN)Initializing builder environment...$(END_COLOR)"

update_version:
	@echo "$(COLOR_YELLOW)Updating version to $(AI_version)...$(END_COLOR)"

init:
	@echo "$(COLOR_GREEN)Initializing project...$(END_COLOR)"

clean:
	@echo "$(COLOR_YELLOW)Cleaning build artifacts...$(END_COLOR)"

clean_all: clean
	@echo "$(COLOR_YELLOW)Performing deep clean (cache and build directories)...$(END_COLOR)"

package:
	@echo "$(COLOR_GREEN)Packaging application...$(END_COLOR)"

generate_md5sum_file:
	@echo "$(COLOR_GREEN)Generating MD5 checksum file...$(END_COLOR)"

upload: generate_md5sum_file
	@echo "$(COLOR_GREEN)Uploading artifacts...$(END_COLOR)"
