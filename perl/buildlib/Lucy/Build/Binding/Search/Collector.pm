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
package Lucy::Build::Binding::Search::Collector;

sub bind_all {
    my $class = shift;
    $class->bind_bitcollector;
    $class->bind_sortcollector;
}

sub bind_bitcollector {
    my $synopsis = <<'END_SYNOPSIS';
    my $bit_vec = Lucy::Object::BitVector->new(
        capacity => $searcher->doc_max + 1,
    );
    my $bit_collector = Lucy::Search::Collector::BitCollector->new(
        bit_vector => $bit_vec, 
    );
    $searcher->collect(
        collector => $bit_collector,
        query     => $query,
    );
END_SYNOPSIS

    my $constructor = <<'END_CONSTRUCTOR';
    my $bit_collector = Lucy::Search::Collector::BitCollector->new(
        bit_vector => $bit_vec,    # required
    );
END_CONSTRUCTOR

    Clownfish::CFC::Binding::Perl::Class->register(
        parcel            => "Lucy",
        class_name        => "Lucy::Search::Collector::BitCollector",
        bind_constructors => ["new"],
        make_pod          => {
            synopsis    => $synopsis,
            constructor => { sample => $constructor },
            methods     => [qw( collect )],
        },
    );

}

sub bind_sortcollector {
    Clownfish::CFC::Binding::Perl::Class->register(
        parcel            => "Lucy",
        class_name        => "Lucy::Search::Collector::SortCollector",
        bind_methods      => [qw( Pop_Match_Docs Get_Total_Hits )],
        bind_constructors => ["new"],
    );

}

1;
