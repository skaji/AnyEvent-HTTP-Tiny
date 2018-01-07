package AnyEvent::HTTP::Tiny;
use strict;
use warnings;

use AnyEvent::HTTP ();
use File::Basename ();
use File::Temp ();

our $VERSION = '0.001';

sub new {
    my ($class, %args) = @_;
    (my $distname = $class) =~ s/::/-/g;
    my $agent = sprintf "%s/%s", $distname, $class->VERSION;
    bless {
        agent => $agent,
        default_headers => {},
        max_redirect => 5,
        timeout => 60,
        %args
    }, $class;
}

sub _make_response {
    my ($self, $data, $hash) = @_;
    my $res = $self->__make_response($data, $hash);
    return $res unless $hash->{Redirect};

    my @redirects;
    my $current = $hash->{Redirect};
    while ($current) {
        my ($data, $hash) = @$current;
        $data = "" unless defined $data;
        push @redirects, $self->__make_response($data, $hash);
        $current = $hash->{Redirect};
    }
    $res->{redirects} = [reverse @redirects];
    return $res;
}

sub __make_response {
    my ($self, $data, $hash) = @_;
    my %headers = (
        map  { my $v = $hash->{$_}; (my $k = $_) =~ s/-/_/g; ($k, $v) }
        grep { !/^[A-Z]/ } keys %$hash
    );
    +{
        success  => $hash->{Status} =~ /^2/ ? 1 : 0,
        reason   => $hash->{Reason},
        status   => $hash->{Status},
        url      => $hash->{URL},
        headers  => \%headers,
        content  => $data,
        $hash->{HTTPVersion} ? (protocol => "HTTP/" . $hash->{HTTPVersion}) : (),
    };
}

sub request {
    my ($self, $method, $url) = (shift, shift, shift);
    my $cb = pop;
    my $hash = shift || {};
    my %headers = ("user-agent" => $self->{agent}, %{$self->{default_headers}}, %{$hash->{headers} || {}});
    my $content = $hash->{content};
    $headers{"content-length"} ||= length $content if defined $content;
    AnyEvent::HTTP::http_request
        $method => $url,
        headers => \%headers,
        timeout => $self->{timeout},
        recurse => $self->{max_redirect},
        defined $content ? (body => $content) : (),
        sub {
            my ($data, $hash) = @_;
            my $res = $self->_make_response($data, $hash);
            $cb->($res);
        },
    ;
}

for my $method (qw(GET POST PUT HEAD)) {
    no strict 'refs';
    *{ lc $method } = sub { splice @_, 1, 0, $method; goto &request }
}

sub _tempfile_for {
    my ($self, $file) = @_;
    my $basename = File::Basename::basename($file);
    my $dirname = File::Basename::dirname($file);
    File::Temp::tempfile("$basename-XXXXX", CLEANUP => 0, DIR => $dirname);
}

sub mirror {
    my ($self, $url, $file) = (shift, shift, shift);
    my $cb = pop;
    my $hash = shift || +{};
    my %headers = ("user-agent" => $self->{agent}, %{$self->{default_headers}}, %{$hash->{headers} || {}});
    if (-f $file) {
        my $mtime = (stat $file)[9];
        $headers{"if-modified-since"} = AnyEvent::HTTP::format_date $mtime;
    }
    my ($tempfh, $tempfile) = $self->_tempfile_for($file);

    AnyEvent::HTTP::http_request
        GET => $url,
        headers => \%headers,
        timeout => $self->{timeout},
        recurse => $self->{max_redirect},
        on_body => sub {
            my ($data, $hash) = @_;
            if ($hash->{Status} =~ /^2/) {
                print {$tempfh} $data;
            }
        },
        sub {
            my ($data, $hash) = @_;
            close $tempfh;
            my $res = $self->_make_response($data, $hash);
            if ($res->{success}) {
                my $actual = -s $tempfile;
                my $expect = $res->{headers}{content_length};
                if (defined $expect and $actual != $expect) {
                    $res->{success} = 0;
                    $res->{status} = 599;
                    $res->{reason} = "Internal Exception";
                    $res->{content} = "Content-Length Header ($expect) != Downloaded data size ($actual)";
                } else {
                    my $err;
                    if (my $last_modified = $res->{headers}{last_modified}) {
                        my $mtime = AnyEvent::HTTP::parse_date $last_modified;
                        utime $mtime, $mtime, $tempfile or do { $err = "failed to set mtime, $!" };
                    }
                    if (!$err) {
                        my $mod = 0666 &~ umask;
                        chmod $mod, $tempfile or do { $err = "failed to chmod, $!" }
                    }
                    if (!$err) {
                        rename $tempfile, $file or do { $err = "failed to rename to $file, $!" };
                    }
                    if ($err) {
                        $res->{success} = 0;
                        $res->{status} = 599;
                        $res->{reason} = "Internal Exception";
                        $res->{content} = $err;
                    }
                }
            }
            unlink $tempfile if -f $tempfile;
            $res->{success} = 1 if $res->{status} == 304;
            $cb->($res);
        },
    ;
}

1;
__END__

=encoding utf-8

=head1 NAME

AnyEvent::HTTP::Tiny - HTTP::Tiny compatible HTTP Client in AnyEvent

=head1 SYNOPSIS

  use AnyEvent::HTTP::Tiny;

  my $http = AnyEvent::HTTP::Tiny->new;
  $http->get("https://www.yahoo.co.jp", sub {
    my $res = shift;
    print "$res->{status} $res->{reason}\n";
  });

=head1 DESCRIPTION

AnyEvent::HTTP::Tiny is

=head1 AUTHOR

Shoichi Kaji <skaji@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2018 Shoichi Kaji <skaji@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
