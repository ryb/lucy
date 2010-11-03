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
use lib 'buildlib';

use Test::More tests => 8;
use LucyX::Simple;
use KinoSearch::Test::TestUtils qw( init_test_index_loc );

my $test_index_loc = init_test_index_loc();

my $index = LucyX::Simple->new(
    language => 'en',
    path     => $test_index_loc,
);

$index->add_doc( { food => 'creamed corn' } );
is( $index->search( query => 'creamed' ), 1, "search warks right after add" );

$index->add_doc( { food => 'creamed spinach' } );
is( $index->search( query => 'creamed' ), 2, "search returns total hits" );

$index->add_doc( { food => 'creamed broccoli' } );
undef $index;
$index = LucyX::Simple->new(
    language => 'en',
    path     => $test_index_loc,
);
is( $index->search( query => 'cream' ), 3, "commit upon destroy" );

while ( my $hit = $index->next ) {
    like( $hit->{food}, qr/cream/, 'next' );
}

$index->add_doc( { band => 'Cream' } );
is( $index->search( query => 'cream' ),
    4, "search uses correct PolyAnalyzer" );

SKIP: {
    skip( "fork on Windows not supported by KS", 1 ) if $^O =~ /mswin/i;

    # We need another one:
    my $test_index_loc = init_test_index_loc();

    # Fork a process that will create an index without explicitly finishing
    # it, and then exit, with the Simple object still in existence at
    # global destruction time.
    my $pid = fork();
    if ( $pid == 0 ) {    # child
        our               # This *has* to be 'our' for the test to work
            $index = LucyX::Simple->new(
            language => 'en',
            path     => $test_index_loc,
            );

        $index->add_doc( { food => 'creamed corn' } );
        exit;
    }
    else {
        waitpid( $pid, 0 );
    }

    my $index = LucyX::Simple->new(
        language => 'en',
        path     => $test_index_loc,
    );

    ok eval {    # This should die if the index wasn't finished.
        $index->search( query => 'creamed' );
        1;
    }, 'Simple finishes indexing during END block (apparently)';

}
