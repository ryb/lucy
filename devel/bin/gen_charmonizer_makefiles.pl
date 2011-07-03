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

package Charmonizer::Build::Makefile;
use File::Find qw();
use FindBin;
use Carp qw( confess );
use Cwd qw( getcwd );

sub new {
    my ( $class, %args ) = @_;

    # Validate args, create object.
    for (qw( dir filename obj_ext exe_ext )) {
        defined $args{$_} or confess("Missing required param '$_'");
    }
    my $dir = $args{dir};
    my $self = bless { 
        dir      => $dir,  
        filename => $args{filename},
        obj_ext  => $args{obj_ext},
        exe_ext  => $args{exe_ext},
    }, $class;

    # Gather source paths, normalized for the target OS.
    my $orig_dir = getcwd();
    chdir($dir);
    -d 'src' or confess("Can't find 'src' directory within '$dir'");
    my ( @h_files, @c_files, @c_tests );
    push @c_files, "charmonize.c";
    File::Find::find( {
        wanted => sub {
            if (/\.c$/) {
                if (/^Test/) {
                    push @c_tests, $File::Find::name;
                }
                else {
                    push @c_files, $File::Find::name;
                }
            }
            elsif (/\.h$/) {
                push @h_files, $File::Find::name;
            }
        },
    }, 'src', );
    chdir($orig_dir);
    $self->{c_files} = [ sort map { $self->pathify($_) } @c_files ];
    $self->{h_files} = [ sort map { $self->pathify($_) } @h_files ];
    $self->{c_tests} = [ sort map { $self->pathify($_) } @c_tests ];

    return $self;
}

sub pathify { confess "abstract method" }

sub unixify {
    my ( $self, $path ) = @_;
    $path =~ tr{\\}{/};
    return $path;
}

sub winnify {
    my ( $self, $path ) = @_;
    $path =~ tr{/}{\\};
    return $path;
}

sub objectify {
    my ( $self, $c_file ) = @_;
    $c_file =~ s/\.c$/$self->{obj_ext}/ or die "No match: $c_file";
    return $c_file;
}

sub build_link_command {
    my ( $self, %args ) = @_;
    my $objects = join( " ", @{ $args{objects} } );
    return "\$(CC) \$(CFLAGS) $objects -o $args{target}";
}

sub test_execs {
    my $self = shift;
    my @test_execs = grep { $_ !~ /Test\.c/ } @_; # skip Test.c entry
    for (@test_execs) {
        s/.*(Test\w+)\.c$/$1$self->{exe_ext}/ or die "no match: $_";
    }
    return @test_execs;
}

sub test_blocks {
    my $self = shift;
    my @c_files = grep { $_ !~ /Test\.c/ } @_; # skip Test.c entry
    my @blocks;
    for my $c_file (@c_files) {
        my $exe = $c_file; 
        $exe =~ s/.*(Test\w+)\.c$/$1$self->{exe_ext}/ or die "no match $exe";
        my $obj = $self->objectify($c_file);
        my $test_obj
            = $self->pathify( $self->objectify("src/Charmonizer/Test.c") );
        my $link_command = $self->build_link_command(
            objects => [ $obj, $test_obj ],
            target  => '$@',
        );
        push @blocks, qq|$exe: $test_obj $obj\n\t$link_command|;
    }
    return @blocks;
}

sub clean_target { confess "abstract method" }

sub clean_target_posix {
    qq|clean:\n\trm -f \$(CLEANABLE)|;
}

sub clean_target_win {
    qq|clean:\n\tCMD /c FOR %i IN (\$(CLEANABLE)) DO IF EXIST %i DEL /F %i|;
}

sub gen_makefile {
    my ( $self, %args ) = @_;
    open my $fh, ">", $args{file} or die "open '$args{file}' failed: $!\n";
    my $license = $self->license;
    my $progname_link_command = $self->build_link_command(
        objects => ['$(OBJS)'],
        target  => '$(PROGNAME)',
    );
    my $content = <<EOT;
# GENERATED BY $FindBin::Script: do not hand-edit!!!
#
$license
$args{top}
PROGNAME= charmonize$self->{exe_ext}

TESTS= $args{test_execs}

OBJS= $args{objs}

TEST_OBJS= $args{test_objs}

HEADERS= $args{headers}

CLEANABLE= \$(OBJS) \$(PROGNAME) \$(TEST_OBJS) \$(TESTS) *.pdb

all: \$(PROGNAME)

\$(PROGNAME): \$(OBJS)
\t$progname_link_command

\$(OBJS) \$(TEST_OBJS): \$(HEADERS)

tests: \$(TESTS)

$args{test_blocks}

$args{clean_target}

EOT
    print $fh $content;
}

sub write_makefile {
    my $self = shift;
    my @objects      = map { $self->objectify($_) } @{ $self->{c_files} };
    my @test_objects = map { $self->objectify($_) } @{ $self->{c_tests} };
    my @test_execs   = $self->test_execs( @{ $self->{c_tests} } );
    my @test_blocks  = $self->test_blocks( @{ $self->{c_tests} } );

    $self->gen_makefile(
        test_execs   => join(" ", @test_execs),
        objs         => join(" ", @objects),
        test_objs    => join(" ", @test_objects),
        headers      => join(" ", @{ $self->{h_files} }),
        test_blocks  => join("\n\n", @test_blocks),
        top          => $self->top,
        clean_target => $self->clean_target,
        file         => $self->{filename},
    );
}

sub license {
    return <<'END_LICENSE';
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
END_LICENSE
}

package Charmonizer::Build::Makefile::Posix;
BEGIN { our @ISA = qw( Charmonizer::Build::Makefile ) }

sub new { 
    my $class = shift;
    return $class->SUPER::new(
        filename => 'Makefile', 
        obj_ext  => '.o',
        exe_ext  => '',
        @_ 
    );
}

sub top {
    return <<END_STUFF;
CC= cc
DEFS=
CFLAGS= -Isrc \$(DEFS)

.c.o:
\t\$(CC) \$(CFLAGS) -c \$*.c -o \$@
END_STUFF
}

sub clean_target { shift->clean_target_posix }
sub pathify      { shift->unixify(@_) }

package Charmonizer::Build::Makefile::MSVC;
BEGIN { our @ISA = qw( Charmonizer::Build::Makefile ) }

sub new { 
    my $class = shift;
    return $class->SUPER::new(
        filename => 'Makefile.MSVC', 
        obj_ext  => '.obj',
        exe_ext  => '.exe',
        @_ 
    );
}


sub top {
    return <<END_STUFF;
CC= cl
DEFS=
CFLAGS= -Isrc -nologo -D_CRT_SECURE_NO_WARNINGS \$(DEFS)

.c.obj:
\t\$(CC) \$(CFLAGS) -c \$< -Fo\$@
END_STUFF
}

sub build_link_command {
    my ( $self, %args ) = @_;
    my $objects = join( " ", @{ $args{objects} } );
    return "link -nologo $objects /OUT:$args{target}";
}

sub pathify      { shift->winnify(@_) }
sub clean_target { shift->clean_target_win }

package Charmonizer::Build::Makefile::MinGW;
BEGIN { our @ISA = qw( Charmonizer::Build::Makefile ) }

sub new { 
    my $class = shift;
    return $class->SUPER::new(
        filename => 'Makefile.MinGW', 
        obj_ext  => '.o',
        exe_ext  => '.exe',
        @_ 
    );
}

sub top {
    return <<END_STUFF;
CC= gcc
DEFS=
CFLAGS= -Isrc \$(DEFS)

.c.o:
\t\$(CC) \$(CFLAGS) -c \$*.c -o \$@
END_STUFF
}

sub pathify      { shift->winnify(@_) }
sub clean_target { shift->clean_target_win }

### actual script follows
package main;

my $makefile_posix = Charmonizer::Build::Makefile::Posix->new( dir => '.' );
my $makefile_msvc  = Charmonizer::Build::Makefile::MSVC->new( dir => '.' );
my $makefile_mingw = Charmonizer::Build::Makefile::MinGW->new( dir => '.' );
$makefile_posix->write_makefile;
$makefile_msvc->write_makefile;
$makefile_mingw->write_makefile;

__END__

=head1 NAME

gen_charmonizer_makefiles.pl

=head1 SYNOPSIS

    gen_charmonizer_makefiles.pl - keeps the Makefiles in sync with the live tree.

=head1 DESCRIPTION

Be sure to run this code from the charmonizer subdirectory (where the
existing Makefiles live).

