SHELLCHECK_VERSION ?= v0.11.0
TOOLS_DIR := .tools/shellcheck
SHELLCHECK_BIN := $(TOOLS_DIR)/bin/shellcheck

############################################################################
# OS/ARCH detection
############################################################################

os := $(shell uname -s)
ifeq ($(os),Darwin)
platform := darwin
else ifeq ($(os),Linux)
platform := linux
else
$(error unsupported OS: $(os))
endif

machine := $(shell uname -m)
ifneq (,$(filter $(machine),x86_64 amd64))
arch := x86_64
else ifneq (,$(filter $(machine),arm64 aarch64))
arch := aarch64
else
$(error unsupported ARCH: $(machine))
endif

############################################################################
# ShellCheck download metadata
############################################################################

archive := shellcheck-$(SHELLCHECK_VERSION).$(platform).$(arch).tar.xz
url := https://github.com/koalaman/shellcheck/releases/download/$(SHELLCHECK_VERSION)/$(archive)

############################################################################
# Targets
############################################################################

.PHONY: install-shellcheck shellcheck lint

install-shellcheck:
	@echo "Installing ShellCheck $(SHELLCHECK_VERSION)..."
	@rm -rf $(TOOLS_DIR)
	@mkdir -p $(TOOLS_DIR)/bin $(TOOLS_DIR)/archive
	@curl -fsSL "$(url)" -o "$(TOOLS_DIR)/archive/$(archive)"
	@tar -xJf "$(TOOLS_DIR)/archive/$(archive)" -C "$(TOOLS_DIR)/archive"
	@cp "$(TOOLS_DIR)/archive/shellcheck-$(SHELLCHECK_VERSION)/shellcheck" "$(SHELLCHECK_BIN)"
	@chmod +x "$(SHELLCHECK_BIN)"
	@"$(SHELLCHECK_BIN)" --version

shellcheck:
	@version="$$( "$(SHELLCHECK_BIN)" --version 2>/dev/null | awk '/^version:/ {print $$2}' )"; \
	if [ "$$version" != "$(SHELLCHECK_VERSION:v%=%)" ]; then \
		if [ -n "$$version" ]; then \
			echo "ShellCheck version $$version found; expected $(SHELLCHECK_VERSION). Reinstalling..."; \
		else \
			echo "ShellCheck not found; installing $(SHELLCHECK_VERSION)..."; \
		fi; \
		$(MAKE) install-shellcheck; \
	fi
	@"$(SHELLCHECK_BIN)" bump_semver.sh

lint: shellcheck
