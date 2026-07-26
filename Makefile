# Makefile — fuse-for-macos-arm64
#
# Overridable variables:
#   CODE_SIGN_IDENTITY   Optional explicit signing identity. If unset, the
#                        Makefile resolves a matching Developer ID Application
#                        certificate from the keychain using DEVELOPMENT_TEAM.
#                        Defaults to '-' (ad-hoc) when no local signing config
#                        is present.
#   DEVELOPMENT_TEAM     10-character Apple Team ID.  Not used for ad-hoc.
#                        Required for notarization.
#   NOTARYTOOL_PROFILE   Keychain profile name for notarytool.
#                        One-time setup:
#                          xcrun notarytool store-credentials fuse-notarize \
#                            --apple-id YOUR_DEV_APPLE_ID \
#                            --team-id  YOUR_TEAM_ID \
#                            --password YOUR_APP_SPECIFIC_PASSWORD

LOCAL_SIGNING_XCCONFIG = fusepb/LocalSigning.xcconfig

ifeq ($(origin CODE_SIGN_IDENTITY), undefined)
LOCAL_CODE_SIGN_IDENTITY := $(shell if [ -f "$(LOCAL_SIGNING_XCCONFIG)" ]; then sed -n 's/^CODE_SIGN_IDENTITY[[:space:]]*=[[:space:]]*//p' "$(LOCAL_SIGNING_XCCONFIG)" | sed -n '1p'; fi)
else
LOCAL_CODE_SIGN_IDENTITY :=
endif

ifeq ($(origin DEVELOPMENT_TEAM), undefined)
EFFECTIVE_DEVELOPMENT_TEAM := $(shell if [ -f "$(LOCAL_SIGNING_XCCONFIG)" ]; then sed -n 's/^DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*//p' "$(LOCAL_SIGNING_XCCONFIG)" | sed -n '1p'; fi)
else
EFFECTIVE_DEVELOPMENT_TEAM := $(DEVELOPMENT_TEAM)
endif

ifeq ($(origin CODE_SIGN_IDENTITY), undefined)
ifeq ($(strip $(EFFECTIVE_DEVELOPMENT_TEAM)),)
EFFECTIVE_CODE_SIGN_IDENTITY := -
else
EFFECTIVE_CODE_SIGN_IDENTITY := $(shell security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Developer ID Application: .* ($(EFFECTIVE_DEVELOPMENT_TEAM))\)"/\1/p' | sed -n '1p')
ifeq ($(strip $(EFFECTIVE_CODE_SIGN_IDENTITY)),)
EFFECTIVE_CODE_SIGN_IDENTITY := $(if $(strip $(LOCAL_CODE_SIGN_IDENTITY)),$(LOCAL_CODE_SIGN_IDENTITY),Developer ID Application)
endif
endif
else
EFFECTIVE_CODE_SIGN_IDENTITY := $(CODE_SIGN_IDENTITY)
endif

NOTARYTOOL_PROFILE  ?= fuse-notarize
NOTARY_POLL_INTERVAL ?= 60

FUSE_APP   = fusepb/build/Deployment/Fuse.app
FUSE_DSYM  = fusepb/build/Deployment/Fuse.app.dSYM
XCODEPROJ  = fusepb/Fuse.xcodeproj
XCODE_BUILD_ROOT = $(CURDIR)/fusepb/build
FUSE_REPO_ROOT = $(CURDIR)
FUSE_SCRIPTS_ROOT = $(FUSE_REPO_ROOT)/fusepb/scripts
FUSE_DEPS_ROOT = $(FUSE_REPO_ROOT)/fusepb/deps
FUSE_THIRD_PARTY_ROOT = $(FUSE_DEPS_ROOT)/third_party
SPARKLE_FRAMEWORK = $(FUSE_APP)/Contents/Frameworks/Sparkle.framework
SPARKLE_VERSION_DIR = $(SPARKLE_FRAMEWORK)/Versions/Current
SPARKLE_INSTALLER_XPC = $(SPARKLE_VERSION_DIR)/XPCServices/Installer.xpc
SPARKLE_DOWNLOADER_XPC = $(SPARKLE_VERSION_DIR)/XPCServices/Downloader.xpc
SPARKLE_AUTOUPDATE = $(SPARKLE_VERSION_DIR)/Autoupdate
SPARKLE_UPDATER_APP = $(SPARKLE_VERSION_DIR)/Updater.app
SPARKLE_SOURCE_FRAMEWORK ?= $(shell find "$(HOME)/Library/Developer/Xcode/DerivedData" -path '*/SourcePackages/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework' -print | sed -n '1p')
SPARKLE_BIN_DIR ?= $(shell find "$(HOME)/Library/Developer/Xcode/DerivedData" -path '*/SourcePackages/artifacts/sparkle/Sparkle/bin' -print | sed -n '1p')
SPARKLE_GENERATE_APPCAST ?= $(SPARKLE_BIN_DIR)/generate_appcast
SPARKLE_GENERATE_KEYS ?= $(SPARKLE_BIN_DIR)/generate_keys
SPARKLE_EDDSA_ACCOUNT ?= ed25519
NOTARIZE_ZIP = Fuse-notarize.zip
DIST_ZIP     = Fuse.zip
FUSE_VERSION = $(shell /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' fusepb/Info-Fuse.plist 2>/dev/null)
RELEASE_VERSION = $(shell /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' fusepb/Info-Fuse.plist 2>/dev/null)
ifeq ($(strip $(RELEASE_VERSION)),)
RELEASE_VERSION := $(FUSE_VERSION)
endif
VERSION ?= $(RELEASE_VERSION)
SPARKLE_ZIP  = Fuse-$(FUSE_VERSION)-sparkle.zip
SPARKLE_CHANGELOG = fusepb/FuseHelp/_English.lproj/changelog.md
SPARKLE_RELEASE_NOTES_EXTRACTOR = fusepb/scripts/extract_release_notes.py
SPARKLE_APPCAST_PATCHER = fusepb/scripts/patch_sparkle_appcast.py
SPARKLE_STAGING_DIR ?= .sparkle-stage
SPARKLE_STAGE_DIR ?= $(SPARKLE_STAGING_DIR)
SPARKLE_STAGING_APPCAST ?= appcast-staging.xml
SPARKLE_APPCAST ?= $(SPARKLE_STAGING_APPCAST)
SPARKLE_STAGING_BASE_URL ?= https://fmeunier.github.io/fuse-for-macos/
SPARKLE_BASE_URL ?= $(SPARKLE_STAGING_BASE_URL)
SPARKLE_DOWNLOAD_URL_PREFIX ?= $(SPARKLE_BASE_URL)
SPARKLE_RELEASE_NOTES_URL_PREFIX ?= $(SPARKLE_BASE_URL)release-notes/
SPARKLE_GITHUB_REPO ?= fmeunier/fuse-for-macos
SPARKLE_GITHUB_RELEASE_TAG ?= sparkle-staging-$(VERSION)
SPARKLE_GITHUB_RELEASE_TITLE ?= Fuse $(VERSION) staging update
SPARKLE_GITHUB_RELEASE_PRERELEASE ?= 1
SPARKLE_GITHUB_VERIFY_TAG ?= 0
SPARKLE_GITHUB_DOWNLOAD_URL_PREFIX = https://github.com/$(SPARKLE_GITHUB_REPO)/releases/download/$(SPARKLE_GITHUB_RELEASE_TAG)/
SPARKLE_STAGE_RELEASE_NOTES_DIR = $(SPARKLE_STAGE_DIR)/release-notes
SPARKLE_STAGE_RELEASE_NOTES_FILE = $(SPARKLE_STAGE_RELEASE_NOTES_DIR)/$(VERSION).md
SPARKLE_STAGE_APPCAST_FILE = $(SPARKLE_STAGE_DIR)/$(SPARKLE_APPCAST)
SPARKLE_STAGE_ARCHIVE = $(SPARKLE_STAGE_DIR)/$(notdir $(SPARKLE_ZIP))
SPARKLE_STAGE_ARCHIVE_RELEASE_NOTES = $(basename $(SPARKLE_STAGE_ARCHIVE)).md
SPARKLE_STAGING_RELEASE_NOTES_DIR = $(SPARKLE_STAGE_RELEASE_NOTES_DIR)
SPARKLE_STAGING_RELEASE_NOTES_FILE = $(SPARKLE_STAGE_RELEASE_NOTES_FILE)
SPARKLE_STAGING_APPCAST_FILE = $(SPARKLE_STAGE_APPCAST_FILE)
SPARKLE_STAGING_ARCHIVE = $(SPARKLE_STAGE_ARCHIVE)
SPARKLE_STAGING_ARCHIVE_RELEASE_NOTES = $(SPARKLE_STAGE_ARCHIVE_RELEASE_NOTES)
DIST_DIR     = Fuse for macOS
DIST_STAGE   = .dist-stage
DIST_SKELETON_DIR = fusepb/release_skeleton/$(DIST_DIR)
DIST_STAGE_DIR = $(DIST_STAGE)/$(DIST_DIR)
NOTARY_SUBMISSION_ID_FILE = .notary-submission-id
NOTARY_LOG_FILE           = .notary-log.json

ifeq ($(EFFECTIVE_CODE_SIGN_IDENTITY),-)
CODESIGN_TIMESTAMP =
else
CODESIGN_TIMESTAMP = --timestamp
endif

FUSE_CODESIGN_TIMESTAMP =

.PHONY: fuse archive adhoc test test-only analyze notarize notarize-submit notarize-status notarize-log notarize-wait notarize-staple notarize-reset embed-sparkle resign-sparkle dist sparkle-zip sparkle-key-setup sparkle-key-public sparkle-key-check sparkle-release-notes sparkle-stage-archive sparkle-github-release sparkle-github-release-staging sparkle-appcast sparkle-appcast-from-stage sparkle-appcast-github sparkle-appcast-staging sparkle-appcast-staging-from-stage sparkle-appcast-staging-github sparkle-stage-clean list-teams clean help

## Run the Quick Look unit test suite (FuseQuickLookTests scheme).
## Requires a macOS host with Xcode and the fuse submodule checked out.
test:
	xcodebuild -project $(XCODEPROJ) -scheme FuseQuickLookTests -configuration Development \
		-destination 'platform=macOS' \
		SYMROOT='$(XCODE_BUILD_ROOT)' OBJROOT='$(XCODE_BUILD_ROOT)' \
		FUSE_REPO_ROOT='$(FUSE_REPO_ROOT)' \
		FUSE_SCRIPTS_ROOT='$(FUSE_SCRIPTS_ROOT)' \
		FUSE_DEPS_ROOT='$(FUSE_DEPS_ROOT)' \
		FUSE_THIRD_PARTY_ROOT='$(FUSE_THIRD_PARTY_ROOT)' \
		test

## Run a single Quick Look unit test by class and method name.
## Usage: make test-only TEST=ClassName/test_method_name
## Example:
##   make test-only TEST=FuseQuickLookImageTests/test_scr_file_produces_bitmap_image
test-only:
	@[ -n "$(TEST)" ] || { echo "error: TEST not specified.  Example: make test-only TEST=FuseQuickLookImageTests/test_scr_file_produces_bitmap_image"; exit 1; }
	xcodebuild -project $(XCODEPROJ) -scheme FuseQuickLookTests -configuration Development \
		-destination 'platform=macOS' \
		SYMROOT='$(XCODE_BUILD_ROOT)' OBJROOT='$(XCODE_BUILD_ROOT)' \
		FUSE_REPO_ROOT='$(FUSE_REPO_ROOT)' \
		FUSE_SCRIPTS_ROOT='$(FUSE_SCRIPTS_ROOT)' \
		FUSE_DEPS_ROOT='$(FUSE_DEPS_ROOT)' \
		FUSE_THIRD_PARTY_ROOT='$(FUSE_THIRD_PARTY_ROOT)' \
		-only-testing:"FuseQuickLookTests/$(TEST)" \
		test

## Run the Xcode static analyser on the Fuse scheme.
## Requires a macOS host with Xcode and the fuse submodule checked out.
analyze:
	xcodebuild -project $(XCODEPROJ) -scheme Fuse -configuration Development \
		-destination 'platform=macOS' \
		SYMROOT='$(XCODE_BUILD_ROOT)' OBJROOT='$(XCODE_BUILD_ROOT)' \
		FUSE_REPO_ROOT='$(FUSE_REPO_ROOT)' \
		FUSE_SCRIPTS_ROOT='$(FUSE_SCRIPTS_ROOT)' \
		FUSE_DEPS_ROOT='$(FUSE_DEPS_ROOT)' \
		FUSE_THIRD_PARTY_ROOT='$(FUSE_THIRD_PARTY_ROOT)' \
		analyze

## Build Fuse.app (Deployment configuration).
## This single Xcode build now also builds the shared staged dependencies plus
## the embedded Quick Look and Spotlight plugin targets.
##
## After xcodebuild, embedded bundled components are re-signed explicitly and
## Fuse.app is then re-signed to seal the corrected nested-code hashes.
fuse:
	$(MAKE) -C fusepb
	@echo "Running Xcode app build"
	xcodebuild -project $(XCODEPROJ) -scheme Fuse -configuration Deployment \
		-destination 'platform=macOS' \
		SYMROOT='$(XCODE_BUILD_ROOT)' OBJROOT='$(XCODE_BUILD_ROOT)' \
		FUSE_REPO_ROOT='$(FUSE_REPO_ROOT)' \
		FUSE_SCRIPTS_ROOT='$(FUSE_SCRIPTS_ROOT)' \
		FUSE_DEPS_ROOT='$(FUSE_DEPS_ROOT)' \
		FUSE_THIRD_PARTY_ROOT='$(FUSE_THIRD_PARTY_ROOT)' \
		CODE_SIGN_IDENTITY="$(EFFECTIVE_CODE_SIGN_IDENTITY)" \
		DEVELOPMENT_TEAM="$(EFFECTIVE_DEVELOPMENT_TEAM)"
	@echo "Re-signing Spotlight importer"
	codesign --sign "$(EFFECTIVE_CODE_SIGN_IDENTITY)" --force --options runtime $(FUSE_CODESIGN_TIMESTAMP) \
		"$(FUSE_APP)/Contents/Library/Spotlight/FuseImporter.mdimporter"
	@echo "Re-signing Quick Look extensions"
	codesign --sign "$(EFFECTIVE_CODE_SIGN_IDENTITY)" --force --options runtime $(FUSE_CODESIGN_TIMESTAMP) \
		--entitlements "fusepb/FuseQuickLookExtension.entitlements" \
		"$(FUSE_APP)/Contents/PlugIns/FuseThumbnailExtension.appex"
	codesign --sign "$(EFFECTIVE_CODE_SIGN_IDENTITY)" --force --options runtime $(FUSE_CODESIGN_TIMESTAMP) \
		--entitlements "fusepb/FuseQuickLookExtension.entitlements" \
		"$(FUSE_APP)/Contents/PlugIns/FusePreviewExtension.appex"
	$(MAKE) embed-sparkle
	$(MAKE) resign-sparkle
	@echo "Re-signing app bundle"
	codesign --sign "$(EFFECTIVE_CODE_SIGN_IDENTITY)" --force --options runtime $(FUSE_CODESIGN_TIMESTAMP) \
		--entitlements "fusepb/Fuse.entitlements" "$(FUSE_APP)"
	@echo "Fuse build complete"

embed-sparkle:
	@if [ -d "$(SPARKLE_FRAMEWORK)" ]; then \
		exit 0 ; \
	fi
	@if [ -z "$(SPARKLE_SOURCE_FRAMEWORK)" ]; then \
		echo "ERROR: Sparkle.framework artifact not found in DerivedData." ; \
		echo "       Run 'xcodebuild -resolvePackageDependencies -project $(XCODEPROJ) -scheme Fuse' and try again." ; \
		false ; \
	fi
	@echo "Embedding Sparkle.framework"
	mkdir -p "$(FUSE_APP)/Contents/Frameworks"
	rm -rf "$(SPARKLE_FRAMEWORK)"
	ditto "$(SPARKLE_SOURCE_FRAMEWORK)" "$(SPARKLE_FRAMEWORK)"

resign-sparkle:
	@if [ ! -d "$(SPARKLE_FRAMEWORK)" ]; then \
		echo "Sparkle.framework not present; skipping Sparkle re-sign" ; \
		exit 0 ; \
	fi
	@echo "Re-signing Sparkle Installer.xpc"
	codesign --sign "$(EFFECTIVE_CODE_SIGN_IDENTITY)" --force --options runtime $(FUSE_CODESIGN_TIMESTAMP) \
		"$(SPARKLE_INSTALLER_XPC)"
	@if [ -d "$(SPARKLE_DOWNLOADER_XPC)" ]; then \
		echo "Re-signing Sparkle Downloader.xpc" ; \
		codesign --sign "$(EFFECTIVE_CODE_SIGN_IDENTITY)" --force --options runtime $(FUSE_CODESIGN_TIMESTAMP) \
			--preserve-metadata=entitlements \
			"$(SPARKLE_DOWNLOADER_XPC)" ; \
	fi
	@echo "Re-signing Sparkle Autoupdate"
	codesign --sign "$(EFFECTIVE_CODE_SIGN_IDENTITY)" --force --options runtime $(FUSE_CODESIGN_TIMESTAMP) \
		"$(SPARKLE_AUTOUPDATE)"
	@echo "Re-signing Sparkle Updater.app"
	codesign --sign "$(EFFECTIVE_CODE_SIGN_IDENTITY)" --force --options runtime $(FUSE_CODESIGN_TIMESTAMP) \
		"$(SPARKLE_UPDATER_APP)"
	@echo "Re-signing Sparkle.framework"
	codesign --sign "$(EFFECTIVE_CODE_SIGN_IDENTITY)" --force --options runtime $(FUSE_CODESIGN_TIMESTAMP) \
		"$(SPARKLE_FRAMEWORK)"

## Build an Xcode archive (.xcarchive) — useful for manual export workflows.
archive:
	xcodebuild archive \
		-project $(XCODEPROJ) \
		-scheme Fuse \
		-destination 'platform=macOS' \
		SYMROOT='$(XCODE_BUILD_ROOT)' OBJROOT='$(XCODE_BUILD_ROOT)' \
		-configuration Deployment \
		-archivePath fusepb/build/Fuse.xcarchive \
		FUSE_REPO_ROOT='$(FUSE_REPO_ROOT)' \
		FUSE_SCRIPTS_ROOT='$(FUSE_SCRIPTS_ROOT)' \
		FUSE_DEPS_ROOT='$(FUSE_DEPS_ROOT)' \
		FUSE_THIRD_PARTY_ROOT='$(FUSE_THIRD_PARTY_ROOT)' \
		CODE_SIGN_IDENTITY="$(EFFECTIVE_CODE_SIGN_IDENTITY)" \
		DEVELOPMENT_TEAM="$(EFFECTIVE_DEVELOPMENT_TEAM)"

## Ad-hoc sign Fuse.app and package it as Fuse-adhoc.zip for local testing.
## The resulting zip is NOT suitable for distribution — Gatekeeper will reject
## it on other machines.  Use 'make notarize && make dist' for that (Phase 2).
adhoc: fuse
	rm -f Fuse-adhoc.zip
	ditto -c -k --keepParent "$(FUSE_APP)" Fuse-adhoc.zip
	@echo "Ad-hoc build packaged as Fuse-adhoc.zip"

## Submit, wait for, and staple a notarization request.
## Use the subtargets below to resume or inspect long-running submissions.
notarize:
	$(MAKE) notarize-submit
	$(MAKE) notarize-wait
	$(MAKE) notarize-staple

## Submit Fuse.app for notarization and store the submission ID locally.
notarize-submit: fuse
	@if [ "$(EFFECTIVE_CODE_SIGN_IDENTITY)" = "-" ]; then \
		echo "ERROR: notarize requires a Developer ID Application identity." ; \
		echo "       Set it in $(LOCAL_SIGNING_XCCONFIG) or re-run with CODE_SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)'" ; \
		false ; \
	fi
	rm -f $(NOTARIZE_ZIP)
	rm -f $(NOTARY_LOG_FILE)
	ditto -c -k --keepParent "$(FUSE_APP)" $(NOTARIZE_ZIP)
	@submission_json=`xcrun notarytool submit $(NOTARIZE_ZIP) --keychain-profile "$(NOTARYTOOL_PROFILE)" --output-format json` ; \
	submission_id=`printf '%s\n' "$$submission_json" | /usr/bin/python3 -c 'import json, sys; print( json.load( sys.stdin )["id"] )'` ; \
	status=`printf '%s\n' "$$submission_json" | /usr/bin/python3 -c 'import json, sys; print( json.load( sys.stdin ).get( "status", "Submitted" ) )'` ; \
	printf '%s\n' "$$submission_id" > "$(NOTARY_SUBMISSION_ID_FILE)" ; \
	echo "Submitted notarization $$submission_id ($$status)" ; \
	echo "Check progress with 'make notarize-status' or wait with 'make notarize-wait'."
	rm -f $(NOTARIZE_ZIP)

## Show status for the current notarization submission.
notarize-status:
	@if [ ! -f "$(NOTARY_SUBMISSION_ID_FILE)" ]; then \
		echo "ERROR: no notarization submission ID found." ; \
		echo "       Run 'make notarize-submit' first." ; \
		false ; \
	fi
	@submission_id=`tr -d '\n' < "$(NOTARY_SUBMISSION_ID_FILE)"` ; \
	info_json=`xcrun notarytool info "$$submission_id" --keychain-profile "$(NOTARYTOOL_PROFILE)" --output-format json` ; \
	printf '%s\n' "$$info_json" | /usr/bin/python3 -c 'import json, sys; info = json.load( sys.stdin ); print( "Submission ID: {}".format( info.get( "id", "unknown" ) ) ); print( "Status: {}".format( info.get( "status", "unknown" ) ) ); summary = info.get( "statusSummary" ); print( "Summary: {}".format( summary ) ) if summary else None; issues = info.get( "issues" ); print( "Issues: {}".format( len( issues ) ) ) if issues else None'

## Fetch the notarization log for the current submission.
notarize-log:
	@if [ ! -f "$(NOTARY_SUBMISSION_ID_FILE)" ]; then \
		echo "ERROR: no notarization submission ID found." ; \
		echo "       Run 'make notarize-submit' first." ; \
		false ; \
	fi
	@submission_id=`tr -d '\n' < "$(NOTARY_SUBMISSION_ID_FILE)"` ; \
	xcrun notarytool log "$$submission_id" "$(NOTARY_LOG_FILE)" --keychain-profile "$(NOTARYTOOL_PROFILE)" ; \
	echo "Saved notarization log to $(NOTARY_LOG_FILE)"

## Poll the current notarization submission until Apple finishes processing it.
notarize-wait:
	@if [ ! -f "$(NOTARY_SUBMISSION_ID_FILE)" ]; then \
		echo "ERROR: no notarization submission ID found." ; \
		echo "       Run 'make notarize-submit' first." ; \
		false ; \
	fi
	@submission_id=`tr -d '\n' < "$(NOTARY_SUBMISSION_ID_FILE)"` ; \
	start_time=`date +%s` ; \
	while :; do \
		info_json=`xcrun notarytool info "$$submission_id" --keychain-profile "$(NOTARYTOOL_PROFILE)" --output-format json` ; \
		status=`printf '%s\n' "$$info_json" | /usr/bin/python3 -c 'import json, sys; print( json.load( sys.stdin ).get( "status", "unknown" ) )'` ; \
		summary=`printf '%s\n' "$$info_json" | /usr/bin/python3 -c 'import json, sys; print( json.load( sys.stdin ).get( "statusSummary", "" ) )'` ; \
		elapsed=$$(( $$(date +%s) - $$start_time )) ; \
		echo "Notarization $$submission_id: $$status after $${elapsed}s" ; \
		if [ -n "$$summary" ]; then echo "  $$summary" ; fi ; \
		case "$$status" in \
		Accepted) \
			break ;; \
		Invalid|Rejected) \
			echo "Notarization failed; fetching log..." ; \
			xcrun notarytool log "$$submission_id" "$(NOTARY_LOG_FILE)" --keychain-profile "$(NOTARYTOOL_PROFILE)" || true ; \
			echo "See $(NOTARY_LOG_FILE) for details." ; \
			false ;; \
		In\ Progress) \
			echo "Still processing on Apple's servers. You can stop waiting and later run 'make notarize-status' or 'make notarize-log'." ; \
			sleep $(NOTARY_POLL_INTERVAL) ;; \
		*) \
			echo "Unexpected notarization status: $$status" ; \
			sleep $(NOTARY_POLL_INTERVAL) ;; \
		esac ; \
	done

## Staple Fuse.app after the current submission has been accepted.
notarize-staple:
	@if [ ! -f "$(NOTARY_SUBMISSION_ID_FILE)" ]; then \
		echo "ERROR: no notarization submission ID found." ; \
		echo "       Run 'make notarize-submit' first." ; \
		false ; \
	fi
	@submission_id=`tr -d '\n' < "$(NOTARY_SUBMISSION_ID_FILE)"` ; \
	status=`xcrun notarytool info "$$submission_id" --keychain-profile "$(NOTARYTOOL_PROFILE)" --output-format json | /usr/bin/python3 -c 'import json, sys; print( json.load( sys.stdin ).get( "status", "unknown" ) )'` ; \
	if [ "$$status" != "Accepted" ]; then \
		echo "ERROR: submission $$submission_id is $$status, not Accepted." ; \
		echo "       Run 'make notarize-status' or 'make notarize-log' for details." ; \
		false ; \
	fi
	xcrun stapler staple "$(FUSE_APP)"

## Clear local notarization state files.
notarize-reset:
	rm -f $(NOTARIZE_ZIP) $(NOTARY_SUBMISSION_ID_FILE) $(NOTARY_LOG_FILE)

## Create the distributable Fuse.zip from a notarized app.
## The final zip contains the staged "Fuse for macOS" folder layout.
dist: notarize
	rm -f $(DIST_ZIP)
	rm -rf $(DIST_STAGE)
	mkdir -p "$(DIST_STAGE)"
	ditto --norsrc "$(DIST_SKELETON_DIR)" "$(DIST_STAGE_DIR)"
	rm -rf "$(DIST_STAGE_DIR)/Fuse.app"
	ditto --norsrc "$(FUSE_APP)" "$(DIST_STAGE_DIR)/Fuse.app"
	mkdir -p "$(DIST_STAGE_DIR)/Debug Symbols"
	rm -rf "$(DIST_STAGE_DIR)/Debug Symbols/Fuse.app.dSYM"
	ditto --norsrc "$(FUSE_DSYM)" "$(DIST_STAGE_DIR)/Debug Symbols/Fuse.app.dSYM"
	python3 -c 'import os, pathlib; root = pathlib.Path("$(DIST_STAGE_DIR)"); [p.unlink() for p in root.rglob("*") if p.name == ".DS_Store" or p.name.startswith("._")]'
	ditto -c -k --sequesterRsrc --keepParent "$(DIST_STAGE_DIR)" "$(DIST_ZIP)"
	rm -rf $(DIST_STAGE)
	@echo "Notarized build packaged as $(DIST_ZIP)"

## Create the Sparkle updater archive from the stapled app bundle only.
## The versioned filename matches the later appcast/archive flow.
sparkle-zip: notarize
	rm -f $(SPARKLE_ZIP)
	ditto -c -k --sequesterRsrc --keepParent "$(FUSE_APP)" "$(SPARKLE_ZIP)"
	@echo "Sparkle update archive packaged as $(SPARKLE_ZIP)"

## Generate or look up the local Sparkle EdDSA signing key in the login Keychain.
## Run this once per Mac, then copy the printed public key into SUPublicEDKey.
sparkle-key-setup:
	@if [ -z "$(SPARKLE_BIN_DIR)" ] || [ ! -x "$(SPARKLE_GENERATE_KEYS)" ]; then \
		echo "ERROR: generate_keys not found in DerivedData." ; \
		echo "       Run 'xcodebuild -resolvePackageDependencies -project $(XCODEPROJ) -scheme Fuse' and try again." ; \
		false ; \
	fi
	"$(SPARKLE_GENERATE_KEYS)" --account "$(SPARKLE_EDDSA_ACCOUNT)"

## Print the existing Sparkle EdDSA public key from the login Keychain.
sparkle-key-public:
	@if [ -z "$(SPARKLE_BIN_DIR)" ] || [ ! -x "$(SPARKLE_GENERATE_KEYS)" ]; then \
		echo "ERROR: generate_keys not found in DerivedData." ; \
		echo "       Run 'xcodebuild -resolvePackageDependencies -project $(XCODEPROJ) -scheme Fuse' and try again." ; \
		false ; \
	fi
	"$(SPARKLE_GENERATE_KEYS)" --account "$(SPARKLE_EDDSA_ACCOUNT)" -p

## Verify that the local Sparkle EdDSA private key is present before appcast generation.
sparkle-key-check:
	@if [ -z "$(SPARKLE_BIN_DIR)" ] || [ ! -x "$(SPARKLE_GENERATE_KEYS)" ]; then \
		echo "ERROR: generate_keys not found in DerivedData." ; \
		echo "       Run 'xcodebuild -resolvePackageDependencies -project $(XCODEPROJ) -scheme Fuse' and try again." ; \
		false ; \
	fi
	@if ! "$(SPARKLE_GENERATE_KEYS)" --account "$(SPARKLE_EDDSA_ACCOUNT)" -p >/dev/null 2>&1; then \
		echo "ERROR: Sparkle EdDSA private key not found in the login Keychain for account $(SPARKLE_EDDSA_ACCOUNT)." ; \
		echo "       Run 'make sparkle-key-setup' once on this Mac to create or import it." ; \
		echo "       After setup, copy the printed public key into SUPublicEDKey when wiring the app." ; \
		false ; \
	fi

## Extract version-specific Markdown release notes from the changelog.
## VERSION defaults to CFBundleShortVersionString and falls back to CFBundleVersion.
sparkle-release-notes:
	mkdir -p "$(SPARKLE_STAGE_RELEASE_NOTES_DIR)"
	python3 "$(SPARKLE_RELEASE_NOTES_EXTRACTOR)" \
		--input "$(SPARKLE_CHANGELOG)" \
		--version "$(VERSION)" \
		--output "$(SPARKLE_STAGE_RELEASE_NOTES_FILE)"
	@echo "Sparkle release notes written to $(SPARKLE_STAGE_RELEASE_NOTES_FILE)"

## Copy the Sparkle ZIP into the staging metadata tree.
sparkle-stage-archive: sparkle-zip
	mkdir -p "$(SPARKLE_STAGE_DIR)"
	cp "$(SPARKLE_ZIP)" "$(SPARKLE_STAGE_ARCHIVE)"
	@echo "Sparkle archive copied to $(SPARKLE_STAGE_ARCHIVE)"

## Create or update a GitHub release and upload the Sparkle ZIP.
sparkle-github-release: sparkle-stage-archive sparkle-release-notes
	@if ! command -v gh >/dev/null 2>&1; then \
		echo "ERROR: gh is not installed." ; \
		false ; \
	fi
	@if [ -z "$(SPARKLE_GITHUB_REPO)" ]; then \
		echo "ERROR: SPARKLE_GITHUB_REPO is empty." ; \
		echo "       Set it explicitly, for example SPARKLE_GITHUB_REPO=owner/repo." ; \
		false ; \
	fi
	@gh auth status >/dev/null
	@mkdir -p "$(SPARKLE_STAGE_DIR)"
	@if gh release view "$(SPARKLE_GITHUB_RELEASE_TAG)" -R "$(SPARKLE_GITHUB_REPO)" >/dev/null 2>&1; then \
		echo "Updating GitHub release $(SPARKLE_GITHUB_RELEASE_TAG) in $(SPARKLE_GITHUB_REPO)" ; \
		if [ "$(SPARKLE_GITHUB_RELEASE_PRERELEASE)" = "1" ]; then prerelease_flag=--prerelease; else prerelease_flag=; fi ; \
		gh release edit "$(SPARKLE_GITHUB_RELEASE_TAG)" -R "$(SPARKLE_GITHUB_REPO)" \
			--title "$(SPARKLE_GITHUB_RELEASE_TITLE)" \
			--notes-file "$(SPARKLE_STAGE_RELEASE_NOTES_FILE)" \
			$$prerelease_flag ; \
	else \
		echo "Creating GitHub release $(SPARKLE_GITHUB_RELEASE_TAG) in $(SPARKLE_GITHUB_REPO)" ; \
		if [ "$(SPARKLE_GITHUB_RELEASE_PRERELEASE)" = "1" ]; then prerelease_flag=--prerelease; else prerelease_flag=; fi ; \
		if [ "$(SPARKLE_GITHUB_VERIFY_TAG)" = "1" ]; then verify_tag_flag=--verify-tag; else verify_tag_flag=; fi ; \
		gh release create "$(SPARKLE_GITHUB_RELEASE_TAG)" -R "$(SPARKLE_GITHUB_REPO)" \
			--title "$(SPARKLE_GITHUB_RELEASE_TITLE)" \
			--notes-file "$(SPARKLE_STAGE_RELEASE_NOTES_FILE)" \
			$$prerelease_flag $$verify_tag_flag ; \
	fi
	gh release upload "$(SPARKLE_GITHUB_RELEASE_TAG)" -R "$(SPARKLE_GITHUB_REPO)" \
		"$(SPARKLE_STAGE_ARCHIVE)" --clobber
	@echo "GitHub release asset URL prefix: $(SPARKLE_GITHUB_DOWNLOAD_URL_PREFIX)"

## Backwards-compatible staging alias.
sparkle-github-release-staging: sparkle-github-release

## Generate a Sparkle appcast and matching staged release notes tree.
## Override SPARKLE_DOWNLOAD_URL_PREFIX if the published archive host differs from Pages.
sparkle-appcast: sparkle-stage-archive sparkle-release-notes
	$(MAKE) sparkle-appcast-from-stage SPARKLE_DOWNLOAD_URL_PREFIX="$(SPARKLE_DOWNLOAD_URL_PREFIX)"

## Backwards-compatible staging alias.
sparkle-appcast-staging: sparkle-appcast

## Generate a Sparkle appcast from the already-staged archive and release notes.
## This avoids rebuilding or repackaging after a GitHub asset upload.
sparkle-appcast-from-stage: sparkle-key-check
	@if [ -z "$(SPARKLE_BIN_DIR)" ] || [ ! -x "$(SPARKLE_GENERATE_APPCAST)" ]; then \
		echo "ERROR: generate_appcast not found in DerivedData." ; \
		echo "       Run 'xcodebuild -resolvePackageDependencies -project $(XCODEPROJ) -scheme Fuse' and try again." ; \
		false ; \
	fi
	@if [ ! -f "$(SPARKLE_STAGE_ARCHIVE)" ]; then \
		echo "ERROR: staged Sparkle archive missing: $(SPARKLE_STAGE_ARCHIVE)" ; \
		echo "       Run 'make sparkle-stage-archive' or 'make sparkle-github-release' first." ; \
		false ; \
	fi
	@if [ ! -f "$(SPARKLE_STAGE_RELEASE_NOTES_FILE)" ]; then \
		echo "ERROR: staged Sparkle release notes missing: $(SPARKLE_STAGE_RELEASE_NOTES_FILE)" ; \
		echo "       Run 'make sparkle-release-notes' or 'make sparkle-github-release' first." ; \
		false ; \
	fi
	rm -f "$(SPARKLE_STAGE_APPCAST_FILE)"
	cp "$(SPARKLE_STAGE_RELEASE_NOTES_FILE)" "$(SPARKLE_STAGE_ARCHIVE_RELEASE_NOTES)"
	"$(SPARKLE_GENERATE_APPCAST)" \
		--download-url-prefix "$(SPARKLE_DOWNLOAD_URL_PREFIX)" \
		--release-notes-url-prefix "$(SPARKLE_RELEASE_NOTES_URL_PREFIX)" \
		-o "$(SPARKLE_STAGE_APPCAST_FILE)" \
		"$(SPARKLE_STAGE_DIR)"
	python3 "$(SPARKLE_APPCAST_PATCHER)" \
		--appcast "$(SPARKLE_STAGE_APPCAST_FILE)" \
		--release-notes-url-prefix "$(SPARKLE_RELEASE_NOTES_URL_PREFIX)"
	@echo "Sparkle appcast written to $(SPARKLE_STAGE_APPCAST_FILE)"

## Backwards-compatible staging alias.
sparkle-appcast-staging-from-stage: sparkle-appcast-from-stage

## Upload the staged archive to GitHub Releases and then generate the appcast
## directly with the final GitHub Releases enclosure URL shape.
sparkle-appcast-github: sparkle-github-release
	$(MAKE) sparkle-appcast-from-stage SPARKLE_DOWNLOAD_URL_PREFIX="$(SPARKLE_GITHUB_DOWNLOAD_URL_PREFIX)"

## Backwards-compatible staging alias.
sparkle-appcast-staging-github: sparkle-appcast-github

## Remove generated Sparkle staging metadata.
sparkle-stage-clean:
	rm -rf "$(SPARKLE_STAGE_DIR)"

## List available signing identities in the keychain.
list-teams:
	security find-identity -v -p codesigning

## Clean the fuse build products.
clean:
	$(MAKE) -C fusepb clean
	xcodebuild -project $(XCODEPROJ) -configuration Deployment clean
	rm -f Fuse-adhoc.zip
	rm -f $(NOTARIZE_ZIP) $(DIST_ZIP) $(SPARKLE_ZIP)
	rm -rf $(DIST_STAGE) "$(SPARKLE_STAGING_DIR)"
	$(MAKE) notarize-reset

## List documented make targets with short descriptions.
help:
	@awk '/^## /{ if (!doc) doc = substr($$0, 4); next } \
	      /^[a-zA-Z][-a-zA-Z_]*:/{ if (doc) { gsub(/:.*/, "", $$1); printf "  %-22s %s\n", $$1, doc }; doc = "" } \
	      !/^[#]/{ doc = "" }' $(MAKEFILE_LIST)
