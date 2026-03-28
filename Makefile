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
NOTARIZE_ZIP = Fuse-notarize.zip
DIST_ZIP     = Fuse.zip
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

.PHONY: fuse archive adhoc notarize notarize-submit notarize-status notarize-log notarize-wait notarize-staple notarize-reset dist list-teams clean

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
	@echo "Re-signing Quick Look plugin"
	codesign --sign "$(EFFECTIVE_CODE_SIGN_IDENTITY)" --force --options runtime $(FUSE_CODESIGN_TIMESTAMP) \
		"$(FUSE_APP)/Contents/Library/QuickLook/FuseGenerator.qlgenerator"
	@echo "Re-signing Spotlight importer"
	codesign --sign "$(EFFECTIVE_CODE_SIGN_IDENTITY)" --force --options runtime $(FUSE_CODESIGN_TIMESTAMP) \
		"$(FUSE_APP)/Contents/Library/Spotlight/FuseImporter.mdimporter"
	@echo "Re-signing app bundle"
	codesign --sign "$(EFFECTIVE_CODE_SIGN_IDENTITY)" --force --options runtime $(FUSE_CODESIGN_TIMESTAMP) \
		--entitlements "fusepb/Fuse.entitlements" "$(FUSE_APP)"
	@echo "Fuse build complete"

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
	cd "$(DIST_STAGE)" && COPYFILE_DISABLE=1 zip -q -r -X "$(CURDIR)/$(DIST_ZIP)" "$(DIST_DIR)"
	rm -rf $(DIST_STAGE)
	@echo "Notarized build packaged as $(DIST_ZIP)"

## List available signing identities in the keychain.
list-teams:
	security find-identity -v -p codesigning

## Clean the fuse build products.
clean:
	$(MAKE) -C fusepb clean
	xcodebuild -project $(XCODEPROJ) -configuration Deployment clean
	rm -f Fuse-adhoc.zip
	rm -f $(NOTARIZE_ZIP) $(DIST_ZIP)
	rm -rf $(DIST_STAGE)
