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

package UnicodeTable;
use strict;

=head1 NAME

UnicodeTable - Create compressed Unicode tables for C programs

=head1 SYNOPSIS

    my $table = UnicodeTable->read(
        filename => $filename,
        type     => 'Enumerated',
        map      => \%map,
    );

    my $comp = $table->compress($shift);

    $comp->dump;

=head1 DESCRIPTION

This module creates compressed tables used to lookup Unicode properties
in C programs. To compress a table, it's split into blocks of a fixed
size. Identical blocks are discovered and only unique blocks are written to
the compressed table. An additional index table is created to map original
block numbers to new ones.

The index tables can then be compressed again using the same algorithm.

Powers of two are used as block sizes, so the table indices to lookup values
can be computed using bit operations.

=head1 METHODS

=head2 new

    my $table = UnicodeTable->new(
        table => \@table,
        max   => $max,
        shift => $shift,
        index => $index,
    );

\@table is an arrayref with the table values, $max is the maximum value.
$shift and $index are used for compressed tables.

=cut

sub new {
    my $class = shift;

    my $opts = @_ == 1 ? $_[0] : {@_};
    my $self = bless( {}, $class );

    for my $name (qw(table max shift index)) {
        $self->{$name} = $opts->{$name};
    }

    $self->{mask} = ( 1 << $self->{shift} ) - 1
        if defined( $self->{shift} );

    return $self;
}

=head2 read

    my $table = UnicodeTable->table(
        filename => $filename,
        type     => $type,
        map      => \%map,
    );

Reads a table from a Unicode data text file. $type is either 'Enumerated'
or 'Boolean'. \%map is a hashref that maps property values to integers.
For booleans, these integers are ORed.

=cut

sub read {
    my $class = shift;

    my $opts = @_ == 1 ? $_[0] : {@_};
    my $max = 0;
    my @table;

    my $filename = $opts->{filename};
    die('filename missing') if !defined($filename);
    my $type = $opts->{type} or die('type missing');
    my $map  = $opts->{map}  or die('map missing');
    $type = lc($type);

    open( my $file, '<', $filename )
        or die("$filename: $!\n");

    while ( my $line = $file->getline ) {
        $line =~ s/\s*(#.*)?\z//s;
        next if $line eq '';
        my ( $chars, $prop ) = split( /\s*;\s*/, $line );
        my $val = $map->{$prop};

        if ( !defined($val) ) {
            if ( $type eq 'boolean' ) {
                next;
            }
            else {
                die("unknown property '$prop'");
            }
        }

        $max = $val if $val > $max;

        if ( $chars =~ /^[0-9A-Fa-f]+\z/ ) {
            my $i = hex($chars);
            if ( $type eq 'boolean' ) {
                $table[$i] |= $val;
            }
            else {
                $table[$i] = $val;
            }
        }
        elsif ( $chars =~ /^(\w+)\.\.(\w+)\z/ ) {
            my ( $l, $r ) = ( hex($1), hex($2) );
            die("invalid range '$chars'") if $l > $r;

            for ( my $i = $l; $i <= $r; ++$i ) {
                if ( $type eq 'boolean' ) {
                    $table[$i] |= $val;
                }
                else {
                    $table[$i] = $val;
                }
            }
        }
        else {
            die("invalid range '$chars'");
        }
    }

    close($file);

    return bless(
        {   table => \@table,
            max   => $max,
        },
        $class
    );
}

=head2 shift

=head2 mask

=head2 max

=head2 index

Accessors

=cut

sub shift {
    return $_[0]->{shift};
}

sub mask {
    return $_[0]->{mask};
}

sub max {
    return $_[0]->{max};
}

sub index {
    my $self = $_[0];
    my $r    = $self->{index};
    $self->{index} = $_[1] if @_ > 1;
    return $r;
}

=head2 set

    $table->set($i, $value);

Set entry at index $i to $value. Don't use with compressed tables.

=cut

sub set {
    my ( $self, $i, $value ) = @_;
    $self->{table}[$i] = $value;
}

=head2 size

    my $size = $table->size;

Storage size of the table in bytes.

=cut

sub size {
    my $self = CORE::shift;

    my $max = $self->{max};
    my $bytes = $max < 0x100 ? 1 : $max < 0x10000 ? 2 : 4;

    return @{ $self->{table} } * $bytes;
}

=head2 lookup

    my $value = $table->lookup($i);

Lookup value at index $i. Also works with compressed tables.

=cut

sub lookup {
    my ( $self, $i ) = @_;

    my $index = $self->{index};

    if ($index) {
        $i = $index->mangle_index($i);
        return 0 if !defined($i);
        return $self->{table}->[$i];
    }
    else {
        return $self->{table}->[$i] || 0;
    }
}

=head2 mangle_index

    my $index = $index_table->mangle_index($i);

Returns a mangled index to be used with a compressed table.

=cut

sub mangle_index {
    my ( $self, $i ) = @_;

    my $table = $self->{table};
    my $shift = $self->{shift};
    my $hi    = $i >> $shift;
    my $index = $self->{index};

    if ($index) {
        $hi = $index->mangle_index($hi);
        return undef if !defined($hi);
    }
    else {
        return undef if $hi >= @$table;
    }

    return ( $table->[$hi] << $shift ) | ( $i & $self->{mask} );
}

=head2 compress

    my $compressed_table = $table->compress($shift);

Returns a compressed version of this table which is linked to a second
index table. Blocks of size (1 << $shift) are used.

=cut

sub compress {
    my ( $self, $shift ) = @_;

    my $table       = $self->{table};
    my $block_size  = 1 << $shift;
    my $block_count = 0;
    my ( @compressed, @index, %blocks );

    for ( my $start = 0; $start < @$table; $start += $block_size ) {
        my @block;

        for ( my $i = $start; $i < $start + $block_size; ++$i ) {
            push( @block, $table->[$i] || 0 );
        }

        my $str = join( '|', @block );
        my $block = $blocks{$str};

        if ( !defined($block) ) {
            $block = $block_count;
            $blocks{$str} = $block;
            ++$block_count;
            push( @compressed, @block );
        }

        push( @index, $block );
    }

    my $index = UnicodeTable->new(
        table => \@index,
        max   => $block_count - 1,
        shift => $shift,
    );

    return UnicodeTable->new(
        table => \@compressed,
        max   => $self->{max},
        shift => $self->{shift},
        index => $index,
    );
}

=head2 dump

    $table->dump($file, $name);

Dump the table as C code to filehandle $file. The table name is $name.

=cut

sub dump {
    my ( $self, $file, $name ) = @_;

    my $table   = $self->{table};
    my $size    = @$table;
    my $uc_name = uc($name);

    print $file (<<"EOF") if $self->{shift};
#define ${uc_name}_SHIFT $self->{shift}
#define ${uc_name}_MASK  $self->{mask}
EOF
    print $file (<<"EOF");
#define ${uc_name}_SIZE  $size

EOF

    my $max           = $self->{max};
    my $bits          = $max < 0x100 ? 8 : $max < 0x10000 ? 16 : 32;
    my $pad           = length($max);
    my $vals_per_line = int( 76 / ( $pad + 2 ) );

    print $file ("static const uint${bits}_t $name\[$size] = {\n");

    my $i = 0;

    while ( $i < $size ) {
        printf $file ( "    \%${pad}d", $table->[$i] );

        my $max = $i + $vals_per_line;
        $max = $size if $max > $size;

        while ( ++$i < $max ) {
            printf $file ( ", \%${pad}d", $table->[$i] );
        }

        print $file (',') if $i < $size;
        print $file ("\n");
    }

    print $file ("};\n");
}

sub calc_sizes {
    my ( $self, $range2, $range1 ) = @_;

    for ( my $shift2 = $range2->[0]; $shift2 <= $range2->[1]; ++$shift2 ) {
        my $comp  = $self->compress($shift2);
        my $index = $comp->index;
        my $size3 = $comp->size;

        for ( my $shift1 = $range1->[0]; $shift1 <= $range1->[1]; ++$shift1 )
        {
            my $comp_index = $index->compress($shift1);

            my $size1 = $comp_index->index->size;
            my $size2 = $comp_index->size;

            printf(
                "shift %2d %2d: %6d + %6d + %6d = %7d bytes, %4d %4d\n",
                $shift1, $shift2, $size1, $size2, $size3,
                $size1 + $size2 + $size3,
                $comp_index->index->max, $comp_index->max,
            );
        }

        print("\n");
    }
}

=head1 AUTHOR

Nick Wellnhofer <wellnhofer@aevum.de>

=cut

1;
