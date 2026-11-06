#!/usr/bin/perl -w

# settings-cocoa-header.pl: generate settings-cocoa.h from settings.dat
# Copyright (c) 2002-2003 Philip Kendall, Fredrick Meunier

# $Id$

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 49 Temple Place, Suite 330, Boston, MA 02111-1307 USA

# Author contact information:

# E-mail: pak21-fuse@srcf.ucam.org

use strict;

use lib 'perl';

use Fuse;

my %options;

while(<>) {

    next if /^\s*$/;
    next if /^\s*#/;

    chomp;

    my( $name, $type, $default, $short, $commandline, $configfile ) =
	split /\s*,\s*/;

    if( not defined $commandline ) {
	$commandline = $name;
	$commandline =~ s/_/-/g;
    }

    if( not defined $configfile ) {
	$configfile = $commandline;
	$configfile =~ s/-//g;
    }

    $options{$name} = { type => $type, default => $default, short => $short,
			commandline => $commandline,
			configfile => $configfile };
}

print Fuse::GPL( 'settings_cocoa.h: Handling configuration settings',
		 'Copyright (c) 2001-2003 Philip Kendall, Fredrick Meunier' );

print << 'CODE';

#ifndef FUSE_SETTINGS_COCOA_H
#define FUSE_SETTINGS_COCOA_H

#import <Foundation/NSArray.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSString.h>

#include "settings.h"

struct settings_cocoa {

CODE

foreach my $name ( sort keys %options ) {

    my $type = $options{$name}->{type};

    if( $type eq 'boolean' or $type eq 'numeric' ) {
	# Do nothing
    } elsif( $type eq 'string' ) {
	# Do nothing
    } elsif( $type eq 'nsarray' ) {
	print "  NSMutableArray *$name;\n";
    } elsif( $type eq 'nsdictionary' ) {
	print "  NSMutableDictionary *$name;\n";
    } elsif( $type eq 'null' ) {
	# Do nothing
    } else {
	die "Unknown setting type `$type'";
    }

}

print << 'CODE';

};

#define NUM_RECENT_ITEMS 10

NSMutableArray*
settings_set_rom_array( settings_info *settings );
void
settings_get_rom_array( settings_info *settings, NSArray *machineroms );
NSInteger
machineroms_compare( id dict1, id dict2, void *context );

CODE

print << 'CODE';
/* Startup preflight cannot use Machine objects before machine_init().
   Generate the same machine/slot relationships directly from settings.dat.
   Each slot includes the default fallback used by the core ROM loader. */
static inline NSArray *
cocoa_startup_rom_candidates( NSString *machine_id, NSUserDefaults *defaults )
{
CODE

my %machine_roms;
foreach my $name ( sort keys %options ) {
  if( $name =~ /^rom_(.*)_\d$/ ) {
    push @{ $machine_roms{$1} }, $name;
  }
}
foreach my $machine ( sort keys %machine_roms ) {
  print "  if( [machine_id isEqualToString:\@\"$machine\"] ) return \@[\n";
  foreach my $name ( @{ $machine_roms{$machine} } ) {
    my $key = $options{$name}->{configfile};
    my $default = $options{$name}->{default};
    print "    \@[ [defaults stringForKey:\@\"$key\"] ?: \@\"\", \@$default ],\n";
  }
  print "  ];\n";
}
print << 'CODE';
  return nil;
}

#endif                          /* #ifndef FUSE_SETTINGS_COCOA_H */
CODE
