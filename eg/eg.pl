#!/usr/bin/env perl
use strict;
use warnings;
use lib "lib", "../lib";

use AnyEvent::HTTP::Tiny;
use AnyEvent;

my $http = AnyEvent::HTTP::Tiny->new;
my @url = (
    "http://www.yahoo.co.jp",
    "https://www.google.com",
    "https://www.google.co.jp",
    "https://perl.org",
    "https://metacpan.org",
);

my $cv = AnyEvent->condvar;
for my $url (@url) {
    $cv->begin;
    $http->get($url, sub {
        my $res = shift;
        warn "$res->{status} $res->{reason}, $res->{url}\n";
        $cv->end;
    });
}
$cv->recv;
