ifeq ($(wildcard ../settings.dat),../settings.dat)
UPSTREAM_ROOT ?= ..
else ifeq ($(wildcard ../fuse/settings.dat),../fuse/settings.dat)
UPSTREAM_ROOT ?= ../fuse
else
UPSTREAM_ROOT ?= ..
endif
COCOA_ROOT ?= .
PERL_ROOT = $(UPSTREAM_ROOT)/perl
UI_ROOT = $(UPSTREAM_ROOT)/ui
Z80_ROOT = $(UPSTREAM_ROOT)/z80

all: settings.h settings.m \
$(Z80_ROOT)/opcodes_base.c $(Z80_ROOT)/z80_cb.c $(Z80_ROOT)/z80_ddfd.c $(Z80_ROOT)/z80_ddfdcb.c \
$(Z80_ROOT)/z80_ed.c settings_cocoa.h options.h options_cocoa.h options.m

settings_cocoa.h: $(UPSTREAM_ROOT)/settings.dat settings-cocoa-header.pl
	cd $(UPSTREAM_ROOT) && perl -Iperl $(COCOA_ROOT)/settings-cocoa-header.pl settings.dat > $(COCOA_ROOT)/$@.tmp && mv $(COCOA_ROOT)/$@.tmp $(COCOA_ROOT)/$@

settings.h: $(UPSTREAM_ROOT)/settings.dat settings-header.pl
	cd $(UPSTREAM_ROOT) && perl -Iperl $(COCOA_ROOT)/settings-header.pl settings.dat > $(COCOA_ROOT)/$@.tmp && mv $(COCOA_ROOT)/$@.tmp $(COCOA_ROOT)/$@

settings.m: $(UPSTREAM_ROOT)/settings.dat $(UPSTREAM_ROOT)/settings.pl
	cd $(UPSTREAM_ROOT) && perl -Iperl settings.pl settings.dat > $(COCOA_ROOT)/settings.m

options_cocoa.h: $(PERL_ROOT)/cpp-perl.pl config.h $(UI_ROOT)/cocoa/options-cocoa-header.pl $(UI_ROOT)/options.dat $(PERL_ROOT)/Fuse.pm $(PERL_ROOT)/Fuse/Dialog.pm
	cd $(UPSTREAM_ROOT) && perl perl/cpp-perl.pl $(COCOA_ROOT)/config.h ui/options.dat | perl -Iperl ui/cocoa/options-cocoa-header.pl - public > $(COCOA_ROOT)/$@.tmp && mv $(COCOA_ROOT)/$@.tmp $(COCOA_ROOT)/$@

options.h: $(PERL_ROOT)/cpp-perl.pl config.h $(UI_ROOT)/cocoa/options-header.pl $(UI_ROOT)/options.dat $(PERL_ROOT)/Fuse.pm $(PERL_ROOT)/Fuse/Dialog.pm
	cd $(UPSTREAM_ROOT) && perl perl/cpp-perl.pl $(COCOA_ROOT)/config.h ui/options.dat | perl -Iperl ui/cocoa/options-header.pl - public > $(COCOA_ROOT)/$@.tmp && mv $(COCOA_ROOT)/$@.tmp $(COCOA_ROOT)/$@

options.m: $(PERL_ROOT)/cpp-perl.pl config.h $(UI_ROOT)/cocoa/options.pl $(UI_ROOT)/options.dat $(PERL_ROOT)/Fuse.pm $(PERL_ROOT)/Fuse/Dialog.pm
	cd $(UPSTREAM_ROOT) && perl perl/cpp-perl.pl $(COCOA_ROOT)/config.h ui/options.dat | perl -Iperl ui/cocoa/options.pl - > $(COCOA_ROOT)/$@.tmp && mv $(COCOA_ROOT)/$@.tmp $(COCOA_ROOT)/$@

$(Z80_ROOT)/opcodes_base.c: $(Z80_ROOT)/opcodes_base.dat $(Z80_ROOT)/z80.pl
	cd $(Z80_ROOT) && perl -I../perl z80.pl opcodes_base.dat > opcodes_base.c

$(Z80_ROOT)/z80_cb.c: $(Z80_ROOT)/opcodes_cb.dat $(Z80_ROOT)/z80.pl
	cd $(Z80_ROOT) && perl -I../perl z80.pl opcodes_cb.dat > z80_cb.c

$(Z80_ROOT)/z80_ddfd.c: $(Z80_ROOT)/opcodes_ddfd.dat $(Z80_ROOT)/z80.pl
	cd $(Z80_ROOT) && perl -I../perl z80.pl opcodes_ddfd.dat > z80_ddfd.c

$(Z80_ROOT)/z80_ddfdcb.c: $(Z80_ROOT)/opcodes_ddfdcb.dat $(Z80_ROOT)/z80.pl
	cd $(Z80_ROOT) && perl -I../perl z80.pl opcodes_ddfdcb.dat > z80_ddfdcb.c

$(Z80_ROOT)/z80_ed.c: $(Z80_ROOT)/opcodes_ed.dat $(Z80_ROOT)/z80.pl
	cd $(Z80_ROOT) && perl -I../perl z80.pl opcodes_ed.dat > z80_ed.c

clean:
	rm options.h options_cocoa.h options.m settings.h settings.m $(Z80_ROOT)/opcodes_base.c $(Z80_ROOT)/z80_cb.c $(Z80_ROOT)/z80_ddfd.c $(Z80_ROOT)/z80_ddfdcb.c $(Z80_ROOT)/z80_ed.c settings_cocoa.h
