#!/usr/bin/env perl
use strict;
use warnings;
use lib "lib", "../lib";

use AnyEvent::HTTP::Tiny;
use AnyEvent;
use Data::Dump;

my $http = AnyEvent::HTTP::Tiny->new;
my $cv = AnyEvent->condvar;
$http->mirror("http://www.yahoo.co.jp", "index.html", sub {
    my $res = shift;
    dd $res;
    $cv->send;
});
$cv->recv;
