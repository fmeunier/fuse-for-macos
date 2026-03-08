# Makefile — fuse-for-macos-arm64
#
# Phase 1: ad-hoc signing.  No Apple Developer account required.
# Phase 2: notarize / dist targets are stubs until enrollment is complete.
#
# Overridable variables:
#   CODE_SIGN_IDENTITY   Signing identity.  Defaults to '-' (ad-hoc).
#                        Phase 2: set to 'Developer ID Application'.
#   DEVELOPMENT_TEAM     10-character Apple Team ID.  Not used for ad-hoc.
#                        Phase 2: required for notarization.
#   NOTARYTOOL_PROFILE   Keychain profile name for notarytool.
#                        Phase 2 one-time setup:
#                          xcrun notarytool store-credentials fuse-notarize \
#                            --apple-id YOUR_DEV_APPLE_ID \
#                            --team-id  YOUR_TEAM_ID \
#                            --password YOUR_APP_SPECIFIC_PASSWORD

CODE_SIGN_IDENTITY  ?= -
DEVELOPMENT_TEAM    ?=
NOTARYTOOL_PROFILE  ?= fuse-notarize

FUSE_APP   = fuse/fusepb/build/Deployment/Fuse.app
XCODEPROJ  = fuse/fusepb/Fuse.xcodeproj

.PHONY: deps third-party plugins fuse archive adhoc notarize dist list-teams clean clean-deps clean-3rdparty clean-plugins

## Build all prerequisites (third-party frameworks and plugins).
deps: third-party plugins

## Build the third-party frameworks (audiofile and libgcrypt).
third-party:
	cd audiofile && xcodebuild -configuration Deployment
	cd libgcrypt && xcodebuild -configuration Deployment

## Build the Fuse plugins (FuseGenerator and FuseImporter).
plugins:
	cd FuseGenerator && xcodebuild -configuration Release
	cd FuseImporter  && xcodebuild -configuration Deployment

## Build Fuse.app (Deployment configuration).
## Run 'make deps' first to ensure all prerequisites are present.
##
## After xcodebuild, the embedded framework binaries are re-signed with
## explicit --identifier flags.  Xcode's CodeSignOnCopy step signs the
## Mach-O binaries without an Info.plist binding, producing a hash-derived
## identifier; the explicit codesign calls below replace that with proper
## reverse-DNS identifiers so dyld can verify them on macOS 26+.
## Fuse.app is then re-signed to seal the corrected framework hashes.
fuse:
	cd fuse/fusepb && make
	xcodebuild -project $(XCODEPROJ) -configuration Deployment \
		CODE_SIGN_IDENTITY="$(CODE_SIGN_IDENTITY)" \
		DEVELOPMENT_TEAM="$(DEVELOPMENT_TEAM)"
	codesign --sign "$(CODE_SIGN_IDENTITY)" --force --options runtime \
		--identifier "net.sourceforge.fuse-for-macosx.gcrypt" \
		"$(FUSE_APP)/Contents/Frameworks/gcrypt.framework/Versions/1.2.4/gcrypt"
	codesign --sign "$(CODE_SIGN_IDENTITY)" --force --options runtime \
		--identifier "net.sourceforge.fuse-for-macosx.audiofile" \
		"$(FUSE_APP)/Contents/Frameworks/audiofile.framework/Versions/0.2.6/audiofile"
	codesign --sign "$(CODE_SIGN_IDENTITY)" --force --options runtime \
		"$(FUSE_APP)/Contents/Frameworks/gcrypt.framework"
	codesign --sign "$(CODE_SIGN_IDENTITY)" --force --options runtime \
		"$(FUSE_APP)/Contents/Frameworks/audiofile.framework"
	codesign --sign "$(CODE_SIGN_IDENTITY)" --force --options runtime \
		"$(FUSE_APP)/Contents/Library/QuickLook/FuseGenerator.qlgenerator"
	codesign --sign "$(CODE_SIGN_IDENTITY)" --force --options runtime \
		"$(FUSE_APP)/Contents/Library/Spotlight/FuseImporter.mdimporter"
	codesign --sign "$(CODE_SIGN_IDENTITY)" --force --options runtime \
		--entitlements "fuse/fusepb/Fuse.entitlements" "$(FUSE_APP)"

## Build an Xcode archive (.xcarchive) — useful for manual export workflows.
archive:
	xcodebuild archive \
		-project $(XCODEPROJ) \
		-configuration Deployment \
		-archivePath fuse/fusepb/build/Fuse.xcarchive \
		CODE_SIGN_IDENTITY="$(CODE_SIGN_IDENTITY)" \
		DEVELOPMENT_TEAM="$(DEVELOPMENT_TEAM)"

## Ad-hoc sign Fuse.app and package it as Fuse-adhoc.zip for local testing.
## The resulting zip is NOT suitable for distribution — Gatekeeper will reject
## it on other machines.  Use 'make notarize && make dist' for that (Phase 2).
adhoc: fuse
	rm -f Fuse-adhoc.zip
	ditto -c -k --keepParent "$(FUSE_APP)" Fuse-adhoc.zip
	@echo "Ad-hoc build packaged as Fuse-adhoc.zip"

## (Phase 2 stub) Notarize and staple Fuse.app.
## Requires a Developer ID Application certificate and a stored notarytool
## keychain profile.  Complete fuse-for-macos-arm64-41j first.
notarize:
	@echo "ERROR: Notarization requires a Developer ID certificate."
	@echo "       Complete Apple Developer enrollment (issue fuse-for-macos-arm64-41j)"
	@echo "       then implement this target (issue fuse-for-macos-arm64-cuo)."
	@exit 1

## (Phase 2 stub) Create the distributable Fuse.zip from a notarized app.
## Depends on 'notarize'.
dist: notarize

## List available signing identities in the keychain.
list-teams:
	security find-identity -v -p codesigning

## Clean the fuse build products.
clean:
	xcodebuild -project $(XCODEPROJ) -configuration Deployment clean
	rm -f Fuse-adhoc.zip

## Clean all prerequisite build products.
clean-deps: clean-3rdparty clean-plugins

## Clean the third-party framework build products.
clean-3rdparty:
	cd audiofile && xcodebuild -configuration Deployment clean
	cd libgcrypt && xcodebuild -configuration Deployment clean

## Clean the plugin build products.
clean-plugins:
	cd FuseGenerator && xcodebuild -configuration Release clean
	cd FuseImporter  && xcodebuild -configuration Deployment clean
