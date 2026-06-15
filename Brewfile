# Brewfile — fuse-for-macos build dependencies
#
# Install all build dependencies at once:
#   brew bundle install --no-upgrade
#
# autoconf, automake, libtool — required by the vendored libgpg-error,
# libgcrypt, and libspectrum autotools build system (invoked by xcodebuild
# as part of the FuseGenerator dependency target).
# ruby — required to run the Perl/Ruby generator scripts in fusepb/ and
# the FuseHelp Jekyll site builder.
brew "autoconf"
brew "automake"
brew "libtool"
brew "ruby"

# jekyll, bundler — required to build the fusepb/FuseHelp documentation
# site (used by the Fuse macOS Help book target in Xcode).
gem "jekyll"
gem "bundler"
