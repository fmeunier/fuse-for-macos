# For command-line debugging, use the Jekyll default destination
TARGET_BUILD_DIR ?= _site

HELP := $(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)
STAMP := $(HELP)/.build-stamp

# Xcode shells have a default environment with no locale settings, so set if undefined (needed by Jekyll to process UTF-8 SCSS)
export LANG ?= en_US.UTF-8

all: $(STAMP)

$(STAMP) : * **/*
	rm -rf "$(HELP)"
	mkdir -p "$(HELP)"
	[ -s "$(HOME)/.rvm/environments/default" ] && . "$(HOME)/.rvm/environments/default" ; \
	PATH="/opt/homebrew/bin:/opt/homebrew/opt/ruby/bin:/usr/local/bin:/usr/local/opt/ruby/bin:$$PATH" ; export PATH ; \
	for GEM_BIN in /opt/homebrew/lib/ruby/gems/*/bin /usr/local/lib/ruby/gems/*/bin ; do \
		[ ! -d "$$GEM_BIN" ] || PATH="$$GEM_BIN:$$PATH" ; \
	done ; export PATH ; \
	JEKYLL=$$(command -v jekyll 2>/dev/null) ; \
	[ -n "$$JEKYLL" ] || [ ! -x /opt/homebrew/bin/jekyll ] || JEKYLL=/opt/homebrew/bin/jekyll ; \
	[ -n "$$JEKYLL" ] || [ ! -x /usr/local/bin/jekyll ] || JEKYLL=/usr/local/bin/jekyll ; \
	[ -n "$$JEKYLL" ] || (echo "error: Jekyll not found - install it via Homebrew or make it available on PATH" ; false) ; \
	"$$JEKYLL" build --destination "$(HELP)"
	for LPROJ in "$(HELP)"/*.lproj ; do \
		LOCALE=$$(basename "$$LPROJ" .lproj) ; \
		echo "Indexing: $$LPROJ" ; \
		hiutil -1 -vv --create --anchors --locale=$$LOCALE --file "$$LPROJ/search.helpindex" "$$LPROJ" 2>&1 | \
		awk "{ if (/error:/) {printf \"error: \" ; err = 1} else {printf \"warning: \"} ; print} END {exit err}" ; \
	done
	touch "$(STAMP)"

.PHONY: all
