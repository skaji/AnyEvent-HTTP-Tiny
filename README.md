[![Build Status](https://travis-ci.org/skaji/AnyEvent-HTTP-Tiny.svg?branch=master)](https://travis-ci.org/skaji/AnyEvent-HTTP-Tiny)

# NAME

AnyEvent::HTTP::Tiny - HTTP::Tiny compatible HTTP Client in AnyEvent

# SYNOPSIS

    use AnyEvent::HTTP::Tiny;

    my $http = AnyEvent::HTTP::Tiny->new;
    $http->get("https://www.yahoo.co.jp", sub {
      my $res = shift;
      print "$res->{status} $res->{reason}\n";
    });

# DESCRIPTION

AnyEvent::HTTP::Tiny is

# AUTHOR

Shoichi Kaji <skaji@cpan.org>

# COPYRIGHT AND LICENSE

Copyright 2018 Shoichi Kaji <skaji@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
