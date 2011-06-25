#!/usr/bin/perl

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;
use File::Find qw( find );
use FindBin;

-d "src" or die "Switch to the directory containg the charmonizer src/.\n";

my (@srcs, @tests, @hdrs);
my $license = "";

sub wanted {
    if (/\.c$/) {
        if (/^Test/) {
            push @tests, $File::Find::name;
        }
        else {
            push @srcs, $File::Find::name;
        }
    }
    elsif (/\.h$/) {
        push @hdrs, $File::Find::name;
    }
}

sub unix_obj {
    my @o = @_;
    s/\.c$/.o/, tr{\\}{/} for @o;
    return @o;
}

sub win_obj {
    my @obj = @_;
    s/\.c$/.obj/, tr{/}{\\} for @obj;
    return @obj;
}

sub unix_tests {
    my @src = @_;
    my @test = map /\b(Test\w+)\.c$/, @src; # \w+ skips the Test.c entry
    my @obj = unix_obj @src;
    my $test_obj;
    @obj = grep /\bTest\.o$/ ? ($test_obj = $_) && 0 : 1, @obj;
    my @block;
    push @block, <<EOT for 0..$#test;
$test[$_]: $test_obj $obj[$_]
	\$(CC) \$(CFLAGS) -o \$@ $test_obj $obj[$_] \$(LIBS)
EOT
    return \@block, \@test;
}

sub win_tests {
    my @src = @_;
    my @test = map /\b(Test\w+)\.c$/, @src; # \w+ skips the Test.c entry
    $_ .= '.exe' for @test;
    my @obj = win_obj @src;
    my $test_obj;
    @obj = grep /\bTest\.obj$/ ? ($test_obj = $_) && 0 : 1, @obj;
    my @block;
    push @block, <<EOT for 0..$#test;
$test[$_]: $test_obj $obj[$_]
	\$(LINKER) $test_obj $obj[$_] /OUT:\$@ \$(LIBS)
EOT
    return \@block, \@test;
}

sub gen_makefile {
    my %args = @_;
    open my $fh, ">Makefile" or die "open Makefile failed: $!\n";
    my $content = <<EOT;
# GENERATED BY $FindBin::Script: do not hand-edit!!!
#
$license
CC= cc
DEFS=
PROGNAME= charmonize
INCLUDES= -I. -Isrc
DEFINES= \$(INCLUDES) \$(DEFS)
CFLAGS= -g \$(DEFINES)
LIBS=

TESTS= $args{test_execs}

OBJS= $args{objs}

TEST_OBJS= $args{test_objs}

HEADERS= $args{headers}

.c.o:
	\$(CC) \$(CFLAGS) -c \$*.c -o \$@

all: \$(PROGNAME)

tests: \$(TESTS)

\$(PROGNAME): \$(OBJS)
	\$(CC) \$(CFLAGS) -o \$(PROGNAME) \$(OBJS) \$(LIBS)

\$(OBJS) \$(TEST_OBJS): \$(HEADERS)

$args{test_blocks}

clean:
	rm -f \$(OBJS) \$(TEST_OBJS) \$(PROGNAME) \$(TESTS) core
EOT
    print $fh $content;
}

use FindBin;
sub gen_makefile_win {
    my %args = @_;
    open my $fh, ">Makefile.win" or die "open Makefile.win failed: $!\n";
    my $content = <<EOT;
# GENERATED BY $FindBin::Script: do not hand-edit!!!
#
$license
CC= cl
DEFS=
PROGNAME= charmonize.exe
LINKER= link -nologo
INCLUDES=  -I. -Isrc
DEFINES= \$(INCLUDES) \$(DEFS) -nologo
CFLAGS= \$(DEFINES)
LIBS=

TESTS= $args{test_execs}

OBJS= $args{objs}

TEST_OBJS= $args{test_objs}

HEADERS= $args{headers}

.c.obj:
	\$(CC) \$(CFLAGS) -c \$< -Fo\$@

all: \$(PROGNAME)

\$(PROGNAME): \$(OBJS)
	\$(LINKER) \$(OBJS) /OUT:\$(PROGNAME) \$(LIBS)

\$(OBJS) \$(TEST_OBJS): \$(HEADERS)

tests: \$(TESTS)

$args{test_blocks}

clean:
	CMD /c FOR %i IN (\$(OBJS) \$(PROGNAME) \$(TEST_OBJS) \$(TESTS) core) DO IF EXIST %i DEL /F %i
EOT
    print $fh $content;
}


### actual script follows

open my $fh, $0 or die "Can't open $0: $!\n";
scalar <$fh>, scalar <$fh>; # skip first 2 lines
while (<$fh>) {
    /^#/ or last;
    $license .= $_;
}

push @srcs, "charmonize.c";
find \&wanted, "src";

my ($unix_test_blocks, $unix_tests) = unix_tests @tests;
gen_makefile
    test_execs  => join(" ", sort @$unix_tests),
    objs        => join(" ", sort +unix_obj @srcs),
    test_objs   => join(" ", sort +unix_obj @tests),
    headers     => join(" ", sort +unix_obj @hdrs),
    test_blocks => join("\n", sort @$unix_test_blocks);

my ($win_test_blocks, $win_tests) = win_tests @tests;
gen_makefile_win
    test_execs  => join(" ", sort @$win_tests),
    objs        => join(" ", sort +win_obj @srcs),
    test_objs   => join(" ", sort +win_obj @tests),
    headers     => join(" ", sort +win_obj @hdrs),
    test_blocks => join("\n", sort @$win_test_blocks);

__END__

=head1 NAME

gen_charmonizer_makefiles.pl

=head1 SYNOPSIS

    gen_charmonizer_makefiles.pl - keeps the Makefiles in sync with the live tree.

=head1 DESCRIPTION

Be sure to run this code from the charmonizer subdirectory (where the
existing Makefiles live).

