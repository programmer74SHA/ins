### Colors Vars
COLOR_GREEN=\033[1;32m
COLOR_YELLOW=\033[1;33m
COLOR_PURPLE=\033[1;35m
END_COLOR=\033[0m
BORDER= echo "$(COLOR_PURPLE)----------------------------------------$(END_COLOR)"
###
.PHONY: update_version build download build_repo clean clean_all init_builder package help status verify

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
ELASTICSEARCH_VERSION=8.15.5

# Default target
.DEFAULT_GOAL := help

build: download build_repo package upload

download: download_elastic_kibana

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


build_repo: init_builder
	@$(BORDER)
	@echo "$(COLOR_GREEN)Building Ubuntu repository from remote sources...$(END_COLOR)"
	@echo "This target replaces download_deb_packages.sh functionality"
	rm -rf $(CACHE_DIR)/ubuntu-repo $(CACHE_DIR)/ubuntu-repo-deb-files
	mkdir -p $(CACHE_DIR)/ubuntu-repo-deb-files

	@$(BORDER)
	@echo "$(COLOR_YELLOW)Downloading .deb packages from ubuntu repository...$(END_COLOR)"
	@$(BORDER)
	@wget -r -np -nd -A "*.deb" -P $(CACHE_DIR)/ubuntu-repo-deb-files \
		-l 15 --timeout=60 --tries=3 --waitretry=5 -e robots=off \
		https://repo.apk-group.net/repository/ubuntu/packages/ 2>&1 | tail -1 || echo "Some packages may have failed to download from ubuntu repo"

	@$(BORDER)
	@echo "$(COLOR_YELLOW)Downloading .deb packages from ubuntu-security repository...$(END_COLOR)"
	@$(BORDER)
	@wget -r -np -nd -A "*.deb" -P $(CACHE_DIR)/ubuntu-repo-deb-files \
		-l 15 --timeout=60 --tries=3 --waitretry=5 -e robots=off \
		https://repo.apk-group.net/repository/ubuntu-security/packages/ 2>&1 | tail -1 || echo "Some packages may have failed to download from ubuntu-security repo"

	@# Validate that packages were downloaded
	@DEB_COUNT=$$(find $(CACHE_DIR)/ubuntu-repo-deb-files -name "*.deb" 2>/dev/null | wc -l); \
	DEB_SIZE=$$(du -sh $(CACHE_DIR)/ubuntu-repo-deb-files 2>/dev/null | cut -f1); \
	echo "Total .deb files downloaded: $$DEB_COUNT ($$DEB_SIZE)"; \
	if [ $$DEB_COUNT -eq 0 ]; then \
		echo "$(COLOR_YELLOW)========================================$(END_COLOR)"; \
		echo "$(COLOR_YELLOW)WARNING: No packages were downloaded!$(END_COLOR)"; \
		echo "$(COLOR_YELLOW)========================================$(END_COLOR)"; \
		echo ""; \
		echo "Possible causes:"; \
		echo "  1. Repository URL is not accessible from this network"; \
		echo "  2. DNS resolution failed for repo.apk-group.net"; \
		echo "  3. GitLab runner needs VPN or network access"; \
		echo "  4. Repository requires authentication"; \
		echo ""; \
		echo "Solutions:"; \
		echo "  1. Ensure GitLab runner has network access to repo.apk-group.net"; \
		echo "  2. Configure DNS to resolve repo.apk-group.net"; \
		echo "  3. Use a different repository URL"; \
		echo "  4. Pre-populate packages manually"; \
		echo ""; \
		exit 1; \
	fi

	@echo "$(COLOR_GREEN)Creating Ubuntu repository structure...$(END_COLOR)"
	mkdir -p $(CACHE_DIR)/ubuntu-repo/pool/main
	cp -v $(CACHE_DIR)/ubuntu-repo-deb-files/*.deb $(CACHE_DIR)/ubuntu-repo/pool/main/

	@echo "$(COLOR_GREEN)Generating Packages index...$(END_COLOR)"
	cd $(CACHE_DIR)/ubuntu-repo && dpkg-scanpackages pool/main /dev/null | gzip -9c > pool/main/Packages.gz
	cd $(CACHE_DIR)/ubuntu-repo && dpkg-scanpackages pool/main /dev/null > pool/main/Packages

	@echo "$(COLOR_GREEN)Packaging repository...$(END_COLOR)"
	tar --use-compress-program=pigz -cvf $(ROLE_DIR)/deploy_apt_repository/files/ubuntu-repository.tar.gz -C $(CACHE_DIR)/ubuntu-repo .

	@echo "$(COLOR_GREEN)Cleaning up temporary files...$(END_COLOR)"
	rm -rf $(CACHE_DIR)/ubuntu-repo $(CACHE_DIR)/ubuntu-repo-deb-files
	@$(BORDER)
	@echo "$(COLOR_GREEN)Ubuntu repository build completed!$(END_COLOR)"


init_builder:
	@echo "$(COLOR_GREEN)Initializing builder environment...$(END_COLOR)"
	@mkdir -p $(CACHE_DIR) $(BUILD_DIR) $(ROLE_DIR)/deploy_apt_repository/files
	@echo "$(COLOR_YELLOW)Checking required tools...$(END_COLOR)"
	@command -v wget >/dev/null 2>&1 || { echo "ERROR: wget is required but not installed. Aborting." >&2; exit 1; }
	@command -v dpkg-scanpackages >/dev/null 2>&1 || { echo "ERROR: dpkg-scanpackages is required but not installed. Install dpkg-dev package. Aborting." >&2; exit 1; }
	@command -v pigz >/dev/null 2>&1 || { echo "ERROR: pigz is required but not installed. Aborting." >&2; exit 1; }
	@command -v tar >/dev/null 2>&1 || { echo "ERROR: tar is required but not installed. Aborting." >&2; exit 1; }
	@command -v skopeo >/dev/null 2>&1 || { echo "WARNING: skopeo is not installed. Docker image downloads will fail." >&2; }
	@echo "$(COLOR_GREEN)All required tools are available.$(END_COLOR)"

update_version:
	@echo "$(COLOR_YELLOW)Updating version to $(AI_version)...$(END_COLOR)"
	@if [ -z "$(AI_version)" ]; then \
		echo "$(COLOR_YELLOW)Warning: AI_version is not set. Using default.$(END_COLOR)"; \
	fi
	@echo "AI_VERSION=$(AI_version)" > ./VERSION
	@echo "$(COLOR_GREEN)Version updated: $(AI_version)$(END_COLOR)"
	@cat ./VERSION

init:
	@$(BORDER)
	@echo "$(COLOR_GREEN)Initializing directories...$(END_COLOR)"
	mkdir -p $(BUILD_DIR) $(CACHE_DIR)

clean:
	@$(BORDER)
	@echo "$(COLOR_GREEN)Cleaning build and cache...$(END_COLOR)"
	rm -rf $(BUILD_DIR) $(CACHE_DIR)

clean_all: clean
	@echo "$(COLOR_YELLOW)Performing deep clean (including downloaded files)...$(END_COLOR)"
	rm -f $(ROLE_DIR)/deploy_elastic_kibana/files/elasticsearch.tar.gz
	rm -f $(ROLE_DIR)/deploy_elastic_kibana/files/kibana.tar.gz
	rm -f $(ROLE_DIR)/deploy_apt_repository/files/ubuntu-repository.tar.gz
	rm -f $(ROLE_DIR)/deploy_apt_repository/files/*.tar.gz
	@echo "$(COLOR_GREEN)Deep clean completed.$(END_COLOR)"

package:
	@$(BORDER)
	@echo "$(COLOR_GREEN)Packaging AI version $(COLOR_YELLOW)$(AI_version)$(END_COLOR)...$(END_COLOR)"
	tar --use-compress-program=pigz -cf $(BUILD_DIR)/ai_$(ai_version)_$(shell date +%Y%m%d%H).tar.gz $(ROLE_DIR)

generate_md5sum_file:
	@$(BORDER)
	@echo "$(COLOR_GREEN)Generating md5 sum file...$(END_COLOR)"
	md5sum $(BUILD_DIR)/ai_$(ai_version)_$(shell date +%Y%m%d%H).tar.gz > $(BUILD_DIR)/ai_$(ai_version)_$(shell date +%Y%m%d%H).tar.gz.md5

upload: generate_md5sum_file
	@$(BORDER)
	@echo "$(COLOR_GREEN)uploading AI version $(COLOR_YELLOW)$(ai_version)$(END_COLOR)...$(END_COLOR)"
	./upload.sh $(BUILD_DIR)/ai_$(ai_version)_$(shell date +%Y%m%d%H).tar.gz siem-installer
	./upload.sh $(BUILD_DIR)/ai_$(ai_version)_$(shell date +%Y%m%d%H).tar.gz.md5 siem-installer

help:
	@$(BORDER)
	@echo "$(COLOR_GREEN)Available targets:$(END_COLOR)"
	@echo "  $(COLOR_YELLOW)build$(END_COLOR)              - Complete build process (download, build_repo, package, upload)"
	@echo "  $(COLOR_YELLOW)download$(END_COLOR)           - Download Elasticsearch and Kibana Docker images"
	@echo "  $(COLOR_YELLOW)build_repo$(END_COLOR)         - Build Ubuntu repository from remote .deb packages"
	@echo "  $(COLOR_YELLOW)package$(END_COLOR)            - Create tarball package of roles directory"
	@echo "  $(COLOR_YELLOW)upload$(END_COLOR)             - Upload package and MD5 checksum"
	@echo "  $(COLOR_YELLOW)clean$(END_COLOR)              - Remove build and cache directories"
	@echo "  $(COLOR_YELLOW)clean_all$(END_COLOR)          - Deep clean including downloaded files"
	@echo "  $(COLOR_YELLOW)init$(END_COLOR)               - Initialize build and cache directories"
	@echo "  $(COLOR_YELLOW)init_builder$(END_COLOR)       - Check dependencies and initialize environment"
	@echo "  $(COLOR_YELLOW)update_version$(END_COLOR)     - Update VERSION file"
	@echo "  $(COLOR_YELLOW)status$(END_COLOR)             - Show status of downloaded files and builds"
	@echo "  $(COLOR_YELLOW)verify$(END_COLOR)             - Verify integrity of downloaded and built files"
	@echo "  $(COLOR_YELLOW)help$(END_COLOR)               - Show this help message"
	@$(BORDER)

status:
	@$(BORDER)
	@echo "$(COLOR_GREEN)Build Status:$(END_COLOR)"
	@echo ""
	@echo "$(COLOR_PURPLE)Version Information:$(END_COLOR)"
	@if [ -f ./VERSION ]; then \
		cat ./VERSION; \
	else \
		echo "  No VERSION file found"; \
	fi
	@echo ""
	@echo "$(COLOR_PURPLE)Downloaded Docker Images:$(END_COLOR)"
	@if [ -f $(ROLE_DIR)/deploy_elastic_kibana/files/elasticsearch.tar.gz ]; then \
		echo "  $(COLOR_GREEN)✓$(END_COLOR) Elasticsearch ($(ELASTICSEARCH_VERSION)) - $$(du -h $(ROLE_DIR)/deploy_elastic_kibana/files/elasticsearch.tar.gz | cut -f1)"; \
	else \
		echo "  $(COLOR_YELLOW)✗$(END_COLOR) Elasticsearch - Not downloaded"; \
	fi
	@if [ -f $(ROLE_DIR)/deploy_elastic_kibana/files/kibana.tar.gz ]; then \
		echo "  $(COLOR_GREEN)✓$(END_COLOR) Kibana ($(KIBANA_VERSION)) - $$(du -h $(ROLE_DIR)/deploy_elastic_kibana/files/kibana.tar.gz | cut -f1)"; \
	else \
		echo "  $(COLOR_YELLOW)✗$(END_COLOR) Kibana - Not downloaded"; \
	fi
	@echo ""
	@echo "$(COLOR_PURPLE)Repository Files:$(END_COLOR)"
	@if [ -f $(ROLE_DIR)/deploy_apt_repository/files/ubuntu-repository.tar.gz ]; then \
		echo "  $(COLOR_GREEN)✓$(END_COLOR) Ubuntu Repository - $$(du -h $(ROLE_DIR)/deploy_apt_repository/files/ubuntu-repository.tar.gz | cut -f1)"; \
	else \
		echo "  $(COLOR_YELLOW)✗$(END_COLOR) Ubuntu Repository - Not built"; \
	fi
	@echo ""
	@echo "$(COLOR_PURPLE)Build Artifacts:$(END_COLOR)"
	@if [ -d $(BUILD_DIR) ] && [ "$$(ls -A $(BUILD_DIR) 2>/dev/null)" ]; then \
		ls -lh $(BUILD_DIR)/ | tail -n +2 | awk '{printf "  %s - %s\n", $$9, $$5}'; \
	else \
		echo "  No build artifacts found"; \
	fi
	@$(BORDER)

verify:
	@$(BORDER)
	@echo "$(COLOR_GREEN)Verifying files...$(END_COLOR)"
	@echo ""
	@ERRORS=0; \
	if [ -f $(ROLE_DIR)/deploy_elastic_kibana/files/elasticsearch.tar.gz ]; then \
		echo -n "Checking Elasticsearch archive... "; \
		if tar -tzf $(ROLE_DIR)/deploy_elastic_kibana/files/elasticsearch.tar.gz >/dev/null 2>&1; then \
			echo "$(COLOR_GREEN)OK$(END_COLOR)"; \
		else \
			echo "$(COLOR_YELLOW)CORRUPTED$(END_COLOR)"; \
			ERRORS=$$((ERRORS + 1)); \
		fi; \
	fi; \
	if [ -f $(ROLE_DIR)/deploy_elastic_kibana/files/kibana.tar.gz ]; then \
		echo -n "Checking Kibana archive... "; \
		if tar -tzf $(ROLE_DIR)/deploy_elastic_kibana/files/kibana.tar.gz >/dev/null 2>&1; then \
			echo "$(COLOR_GREEN)OK$(END_COLOR)"; \
		else \
			echo "$(COLOR_YELLOW)CORRUPTED$(END_COLOR)"; \
			ERRORS=$$((ERRORS + 1)); \
		fi; \
	fi; \
	if [ -f $(ROLE_DIR)/deploy_apt_repository/files/ubuntu-repository.tar.gz ]; then \
		echo -n "Checking Ubuntu repository archive... "; \
		if tar -tzf $(ROLE_DIR)/deploy_apt_repository/files/ubuntu-repository.tar.gz >/dev/null 2>&1; then \
			echo "$(COLOR_GREEN)OK$(END_COLOR)"; \
		else \
			echo "$(COLOR_YELLOW)CORRUPTED$(END_COLOR)"; \
			ERRORS=$$((ERRORS + 1)); \
		fi; \
	fi; \
	if [ -f $(BUILD_DIR)/ai_*.tar.gz ]; then \
		for file in $(BUILD_DIR)/ai_*.tar.gz; do \
			echo -n "Checking $$file... "; \
			if tar -tzf $$file >/dev/null 2>&1; then \
				echo "$(COLOR_GREEN)OK$(END_COLOR)"; \
			else \
				echo "$(COLOR_YELLOW)CORRUPTED$(END_COLOR)"; \
				ERRORS=$$((ERRORS + 1)); \
			fi; \
		done; \
	fi; \
	echo ""; \
	if [ $$ERRORS -eq 0 ]; then \
		echo "$(COLOR_GREEN)All files verified successfully!$(END_COLOR)"; \
	else \
		echo "$(COLOR_YELLOW)Found $$ERRORS corrupted file(s)$(END_COLOR)"; \
	fi
	@$(BORDER)
