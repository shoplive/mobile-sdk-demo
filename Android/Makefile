# Shoplive Onboarding Demo (Android)
#
#   make                 — interactive menu
#   make sdk-dev-on / sdk-dev-off / sdk-dev-status
#
# matrix-sdk-android dev mode: symlink the SDK at the project root so
# settings.gradle.kts includes its modules via project(). Removing the links
# falls back to the customer AAR path.

.DEFAULT_GOAL := menu

# Default SDK path (relative to Android/). Overridable at the prompt.
SDK_PATH_DEFAULT := ../../matrix-sdk-android

.PHONY: menu help sdk-dev-on sdk-dev-off sdk-dev-status

menu help:
	@echo ""
	@echo "  Shoplive Onboarding Demo — Android"
	@echo "  ---------------------------------"
	@echo "  1) Enable matrix-sdk-android dev mode"
	@echo "  2) Disable matrix-sdk-android dev mode  (restore customer AAR)"
	@echo "  3) Show dev-mode status"
	@echo "  q) Quit"
	@echo ""
	@printf "  Choice: "; \
	read choice; \
	case "$$choice" in \
		1) $(MAKE) sdk-dev-on ;; \
		2) $(MAKE) sdk-dev-off ;; \
		3) $(MAKE) sdk-dev-status ;; \
		q|Q|"") echo "  Bye." ;; \
		*) echo "  Unknown choice: $$choice"; exit 1 ;; \
	esac

# ── Dev mode ON ──────────────────────────────────────────────────────────────
# 1) Prompt for matrix-sdk-android path → root symlink
# 2) lines / scripts/sdk-kotlin-metadata.pro (relative to the root link)
sdk-dev-on:
	@echo ""
	@echo "  Enable matrix-sdk-android dev mode"
	@echo "  (Gradle switches automatically when the links exist)"
	@echo ""
	@printf "  SDK path [$(SDK_PATH_DEFAULT)]: "; \
	read input; \
	path="$${input:-$(SDK_PATH_DEFAULT)}"; \
	if [ ! -d "$$path" ]; then \
		echo "  ✗ Directory not found: $$path"; exit 1; \
	fi; \
	if [ ! -d "$$path/lines/international/shoplive-player-sdk" ]; then \
		echo "  ✗ Missing international line module:"; \
		echo "    $$path/lines/international/shoplive-player-sdk"; \
		exit 1; \
	fi; \
	ln -sfn "$$path" matrix-sdk-android; \
	ln -sfn matrix-sdk-android/lines lines; \
	mkdir -p scripts; \
	ln -sfn ../matrix-sdk-android/scripts/sdk-kotlin-metadata.pro scripts/sdk-kotlin-metadata.pro; \
	echo ""; \
	echo "  ✓ matrix-sdk-android → $$(readlink matrix-sdk-android)"; \
	echo "  ✓ lines               → $$(readlink lines)"; \
	echo "  ✓ scripts/sdk-kotlin-metadata.pro → $$(readlink scripts/sdk-kotlin-metadata.pro)"; \
	echo ""; \
	echo "  Gradle Sync in Android Studio, then Run the app."; \
	echo "  SDK edits land in the linked matrix-sdk-android checkout (its own git)."

# ── Dev mode OFF ─────────────────────────────────────────────────────────────
# Remove symlinks only → settings / app / integration fall back to customer AARs.
sdk-dev-off:
	@echo ""
	@echo "  Disable matrix-sdk-android dev mode"
	@removed=0; \
	for p in matrix-sdk-android lines scripts/sdk-kotlin-metadata.pro; do \
		if [ -L "$$p" ]; then \
			rm -f "$$p"; \
			echo "  ✓ Removed: $$p"; \
			removed=1; \
		elif [ -e "$$p" ]; then \
			echo "  ! Not a symlink, skipped: $$p"; \
		fi; \
	done; \
	if [ "$$removed" = "0" ]; then \
		echo "  (No dev-mode links to remove — already on customer AARs)"; \
	fi; \
	echo ""; \
	echo "  Building with customer AARs. Gradle Sync, then continue."

sdk-dev-status:
	@echo ""
	@if [ -L matrix-sdk-android ] && [ -d matrix-sdk-android/lines/international/shoplive-player-sdk ]; then \
		echo "  Status: dev mode ON"; \
		echo "  matrix-sdk-android → $$(readlink matrix-sdk-android)"; \
		echo "  Resolved path: $$(cd matrix-sdk-android && pwd -P)"; \
		[ -L lines ] && echo "  lines → $$(readlink lines)"; \
		[ -L scripts/sdk-kotlin-metadata.pro ] && echo "  scripts/sdk-kotlin-metadata.pro → $$(readlink scripts/sdk-kotlin-metadata.pro)"; \
	else \
		echo "  Status: dev mode OFF (customer AAR)"; \
		[ -e matrix-sdk-android ] && echo "  ! matrix-sdk-android exists but is not a valid SDK link."; \
	fi; \
	echo ""
