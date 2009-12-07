use strict;
use warnings;

use Test::More tests => 13;
use Boilerplater::Type;
use Boilerplater::Parser;

BEGIN { use_ok('Boilerplater::Variable') }

my $parser = Boilerplater::Parser->new;
$parser->parcel_definition('parcel Boil;')
    or die "failed to process parcel_definition";

sub new_type { $parser->type(shift) }

eval {
    my $death = Boilerplater::Variable->new(
        micro_sym => 'foo',
        type      => new_type('int'),
        extra_arg => undef,
    );
};
like( $@, qr/extra_arg/, "Extra arg kills constructor" );

eval { my $death = Boilerplater::Variable->new( micro_sym => 'foo' ) };
like( $@, qr/type/, "type is required" );
eval { my $death = Boilerplater::Variable->new( type => new_type('i32_t') ) };
like( $@, qr/micro_sym/, "micro_sym is required" );

my $var = Boilerplater::Variable->new(
    micro_sym => 'foo',
    type      => new_type('float*')
);
is( $var->local_c,           'float* foo',  "local_c" );
is( $var->local_declaration, 'float* foo;', "declaration" );
ok( $var->local, "default to local access" );

$var = Boilerplater::Variable->new(
    micro_sym => 'foo',
    type      => new_type('float[1]')
);
is( $var->local_c, 'float foo[1]',
    "to_c appends array to var name rather than type specifier" );

$var = Boilerplater::Variable->new(
    parcel      => 'Boil',
    micro_sym   => 'foo',
    type        => new_type("Foo*"),
    class_name  => 'Crustacean::Lobster::LobsterClaw',
    class_cnick => 'LobClaw',
);
is( $var->global_c, 'boil_Foo* boil_LobClaw_foo', "global_c" );

isa_ok( $parser->var_declaration_statement($_)->{declared},
    "Boilerplater::Variable", "var_declaration_statement: $_" )
    for (
    'parcel int foo;',
    'private Obj *obj;',
    'public inert i32_t **foo;',
    'Dog *fido;'
    );