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

package Lucy;

use 5.008003;
use Exporter;

our $VERSION = '0.003000';
$VERSION = eval $VERSION;

use XSLoader;
# This loads a large number of disparate subs.
BEGIN { XSLoader::load( 'Lucy', '0.003000' ) }

BEGIN {
    push our @ISA, 'Exporter';
    our @EXPORT_OK = qw( to_clownfish to_perl kdump );
}

use Lucy::Autobinding;

sub kdump {
    require Data::Dumper;
    my $kdumper = Data::Dumper->new( [@_] );
    $kdumper->Sortkeys( sub { return [ sort keys %{ $_[0] } ] } );
    $kdumper->Indent(1);
    warn $kdumper->Dump;
}

sub error {$Lucy::Object::Err::error}

{
    package Lucy::Util::IndexFileNames;
    BEGIN {
        push our @ISA, 'Exporter';
        our @EXPORT_OK = qw(
            extract_gen
            latest_snapshot
        );
    }
}

{
    package Lucy::Util::StringHelper;
    BEGIN {
        push our @ISA, 'Exporter';
        our @EXPORT_OK = qw(
            utf8_flag_on
            utf8_flag_off
            to_base36
            from_base36
            utf8ify
            utf8_valid
            cat_bytes
        );
    }
}

{
    package Lucy::Analysis::Inversion;

    our %new_PARAMS = (
        # params
        text => undef
    );
}

{
    package Lucy::Analysis::Token;

    our %new_PARAMS = (
        text         => undef,
        start_offset => undef,
        end_offset   => undef,
        pos_inc      => 1,
        boost        => 1.0,
    );
}

{
    package Lucy::Analysis::RegexTokenizer;

    sub compile_token_re { return qr/$_[1]/ }

    sub new {
        my ( $either, %args ) = @_;
        my $token_re = delete $args{token_re};
        $args{pattern} = "$token_re" if $token_re;
        return $either->_new(%args);
    }
}

{
    package Lucy::Document::Doc;
    use Storable qw( nfreeze thaw );
    use bytes;
    no bytes;

    our %new_PARAMS = (
        fields => undef,
        doc_id => 0,
    );

    use overload
        fallback => 1,
        '%{}'    => \&get_fields;

    sub serialize_fields {
        my ( $self, $outstream ) = @_;
        my $buf = nfreeze( $self->get_fields );
        $outstream->write_c32( bytes::length($buf) );
        $outstream->print($buf);
    }

    sub deserialize_fields {
        my ( $self, $instream ) = @_;
        my $len = $instream->read_c32;
        my $buf;
        $instream->read( $buf, $len );
        $self->set_fields( thaw($buf) );
    }
}

{
    package Lucy::Document::HitDoc;

    our %new_PARAMS = (
        fields => undef,
        score  => 0,
        doc_id => 0,
    );
}

{
    package Lucy::Object::I32Array;
    our %new_PARAMS = ( ints => undef );
}

{
    package Lucy::Object::LockFreeRegistry;
    no warnings 'redefine';
    sub DESTROY { }    # leak all
}

{
    package Lucy::Object::Obj;
    use Lucy qw( to_clownfish to_perl );
    sub load { return $_[0]->_load( to_clownfish( $_[1] ) ) }
}

{
    package Lucy::Object::VTable;

    sub find_parent_class {
        my ( undef, $package ) = @_;
        no strict 'refs';
        for my $parent ( @{"$package\::ISA"} ) {
            return $parent if $parent->isa('Lucy::Object::Obj');
        }
        return;
    }

    sub fresh_host_methods {
        my ( undef, $package ) = @_;
        no strict 'refs';
        my $stash = \%{"$package\::"};
        my $methods
            = Lucy::Object::VArray->new( capacity => scalar keys %$stash );
        while ( my ( $symbol, $glob ) = each %$stash ) {
            next if ref $glob;
            next unless *$glob{CODE};
            $methods->push( Lucy::Object::CharBuf->new($symbol) );
        }
        return $methods;
    }

    sub _register {
        my ( undef, %args ) = @_;
        my $singleton_class = $args{singleton}->get_name;
        my $parent_class    = $args{parent}->get_name;
        if ( !$singleton_class->isa($parent_class) ) {
            no strict 'refs';
            push @{"$singleton_class\::ISA"}, $parent_class;
        }
    }

    our %singleton_PARAMS = (
        class_name => undef,
        parent     => undef,
    );

    no warnings 'redefine';
    sub DESTROY { }    # leak all
}

{
    package Lucy::Index::Indexer;

    sub new {
        my ( $either, %args ) = @_;
        my $flags = 0;
        $flags |= CREATE   if delete $args{'create'};
        $flags |= TRUNCATE if delete $args{'truncate'};
        return $either->_new( %args, flags => $flags );
    }

    our %add_doc_PARAMS = ( doc => undef, boost => 1.0 );
}

{
    package Lucy::Index::IndexReader;
    use Carp;

    sub new {
        confess(
            "IndexReader is an abstract class; use open() instead of new()");
    }
    sub lexicon {
        my $self       = shift;
        my $lex_reader = $self->fetch("Lucy::Index::LexiconReader");
        return $lex_reader->lexicon(@_) if $lex_reader;
        return;
    }
    sub posting_list {
        my $self         = shift;
        my $plist_reader = $self->fetch("Lucy::Index::PostingListReader");
        return $plist_reader->posting_list(@_) if $plist_reader;
        return;
    }
    sub offsets { shift->_offsets->to_arrayref }
}

{
    package Lucy::Index::PolyReader;
    use Lucy qw( to_clownfish );

    sub _try_read_snapshot {
        my ( undef, %args ) = @_;
        my ( $snapshot, $folder, $path ) = @args{qw( snapshot folder path )};
        eval { $snapshot->read_file( folder => $folder, path => $path ); };
        if   ($@) { return Lucy::Object::CharBuf->new($@) }
        else      { return undef }
    }

    sub _try_open_segreaders {
        my ( $self, $segments ) = @_;
        my $schema   = $self->get_schema;
        my $folder   = $self->get_folder;
        my $snapshot = $self->get_snapshot;
        my $seg_readers
            = Lucy::Object::VArray->new( capacity => scalar @$segments );
        my $segs = to_clownfish($segments);    # FIXME: Don't convert twice.
        eval {
            # Create a SegReader for each segment in the index.
            my $num_segs = scalar @$segments;
            for ( my $seg_tick = 0; $seg_tick < $num_segs; $seg_tick++ ) {
                my $seg_reader = Lucy::Index::SegReader->new(
                    schema   => $schema,
                    folder   => $folder,
                    segments => $segs,
                    seg_tick => $seg_tick,
                    snapshot => $snapshot,
                );
                $seg_readers->push($seg_reader);
            }
        };
        if ($@) {
            return Lucy::Object::CharBuf->new($@);
        }
        return $seg_readers;
    }
}

{
    package Lucy::Index::Segment;
    use Lucy qw( to_clownfish );
    sub store_metadata {
        my ( $self, %args ) = @_;
        $self->_store_metadata( %args,
            metadata => to_clownfish( $args{metadata} ) );
    }
}

{
    package Lucy::Index::SegReader;

    sub _try_init_components {
        my $self = shift;
        my $arch = $self->get_schema->get_architecture;
        eval { $arch->init_seg_reader($self); };
        if ($@) { return Lucy::Object::CharBuf->new($@); }
        return;
    }
}

{
    package Lucy::Index::SortCache;
    our %value_PARAMS = ( ord => undef, );
}

{
    package Lucy::Search::Compiler;
    use Carp;
    use Scalar::Util qw( blessed );

    sub new {
        my ( $either, %args ) = @_;
        if ( !defined $args{boost} ) {
            confess("'parent' is not a Query")
                unless ( blessed( $args{parent} )
                and $args{parent}->isa("Lucy::Search::Query") );
            $args{boost} = $args{parent}->get_boost;
        }
        return $either->do_new(%args);
    }
}

{
    package Lucy::Search::Query;

    sub make_compiler {
        my ( $self, %args ) = @_;
        $args{boost} = $self->get_boost unless defined $args{boost};
        return $self->_make_compiler(%args);
    }
}

{
    package Lucy::Search::SortRule;

    my %types = (
        field  => FIELD(),
        score  => SCORE(),
        doc_id => DOC_ID(),
    );

    sub new {
        my ( $either, %args ) = @_;
        my $type = delete $args{type} || 'field';
        confess("Invalid type: '$type'") unless defined $types{$type};
        return $either->_new( %args, type => $types{$type} );
    }
}

{
    package Lucy::Object::BitVector;
    sub to_arrayref { shift->to_array->to_arrayref }
}

{
    package Lucy::Object::ByteBuf;
    {
        # Override autogenerated deserialize binding.
        no warnings 'redefine';
        sub deserialize { shift->_deserialize(@_) }
    }
}

{
    package Lucy::Object::ViewByteBuf;
    use Carp;
    sub new { confess "ViewByteBuf objects can only be created from C." }
}

{
    package Lucy::Object::CharBuf;

    {
        # Defeat obscure bugs in the XS auto-generation by redefining clone()
        # and deserialize().  (Because of how the typemap works for CharBuf*,
        # the auto-generated methods return UTF-8 Perl scalars rather than
        # actual CharBuf objects.)
        no warnings 'redefine';
        sub clone       { shift->_clone(@_) }
        sub deserialize { shift->_deserialize(@_) }
    }
}

{
    package Lucy::Object::ViewCharBuf;
    use Carp;
    sub new { confess "ViewCharBuf has no public constructor." }
}

{
    package Lucy::Object::ZombieCharBuf;
    use Carp;
    sub new { confess "ZombieCharBuf objects can only be created from C." }
    no warnings 'redefine';
    sub DESTROY { }
}

{
    package Lucy::Object::Err;
    sub do_to_string { shift->to_string }
    use Scalar::Util qw( blessed );
    use Carp qw( confess longmess );
    use overload
        '""'     => \&do_to_string,
        fallback => 1;

    sub new {
        my ( $either, $message ) = @_;
        my ( undef, $file, $line ) = caller;
        $message .= ", $file line $line\n";
        return $either->_new( mess => Lucy::Object::CharBuf->new($message) );
    }

    sub do_throw {
        my $err      = shift;
        my $longmess = longmess();
        $longmess =~ s/^\s*/\t/;
        $err->cat_mess($longmess);
        die $err;
    }

    our $error;
    sub set_error {
        my $val = $_[1];
        if ( defined $val ) {
            confess("Not a Lucy::Object::Err")
                unless ( blessed($val)
                && $val->isa("Lucy::Object::Err") );
        }
        $error = $val;
    }
    sub get_error {$error}
}

{
    package Lucy::Object::Hash;
    no warnings 'redefine';
    sub deserialize { shift->_deserialize(@_) }
}

{
    package Lucy::Object::VArray;
    no warnings 'redefine';
    sub clone       { CORE::shift->_clone }
    sub deserialize { CORE::shift->_deserialize(@_) }
}

{
    package Lucy::Store::FileHandle;
    BEGIN {
        push our @ISA, 'Exporter';
        our @EXPORT_OK = qw( build_fh_flags );
    }

    sub build_fh_flags {
        my $args  = shift;
        my $flags = 0;
        $flags |= FH_CREATE     if delete $args->{create};
        $flags |= FH_READ_ONLY  if delete $args->{read_only};
        $flags |= FH_WRITE_ONLY if delete $args->{write_only};
        $flags |= FH_EXCLUSIVE  if delete $args->{exclusive};
        return $flags;
    }

    sub open {
        my ( $either, %args ) = @_;
        $args{flags} ||= 0;
        $args{flags} |= build_fh_flags( \%args );
        return $either->_open(%args);
    }
}

{
    package Lucy::Store::FSFileHandle;

    sub open {
        my ( $either, %args ) = @_;
        $args{flags} ||= 0;
        $args{flags} |= Lucy::Store::FileHandle::build_fh_flags( \%args );
        return $either->_open(%args);
    }
}

{
    package Lucy::Store::FSFolder;
    use File::Spec::Functions qw( rel2abs );
    sub absolutify { return rel2abs( $_[1] ) }
}

{
    package Lucy::Store::RAMFileHandle;

    sub open {
        my ( $either, %args ) = @_;
        $args{flags} ||= 0;
        $args{flags} |= Lucy::Store::FileHandle::build_fh_flags( \%args );
        return $either->_open(%args);
    }
}

{
    package Lucy::Util::Debug;
    BEGIN {
        push our @ISA, 'Exporter';
        our @EXPORT_OK = qw(
            DEBUG
            DEBUG_PRINT
            DEBUG_ENABLED
            ASSERT
            set_env_cache
            num_allocated
            num_freed
            num_globals
        );
    }
}

{
    package Lucy::Object::Host;
    BEGIN {
        if ( !__PACKAGE__->isa('Lucy::Object::Obj') ) {
            push our @ISA, 'Lucy::Object::Obj';
        }
    }
}

1;

__END__


