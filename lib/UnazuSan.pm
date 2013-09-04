package UnazuSan;
use 5.010;
use strict;
use warnings;

our $VERSION = "0.01";

use AnySan;
use AnySan::Provider::IRC;
use Encode qw/decode_utf8/;

sub new {
    my $class = shift;
    my %args = @_ == 1 ? %{$_[0]} : @_;
    my $self = bless \%args, $class;

    $self->{nickname}           //= 'unazu_san';
    $self->{port}               ||= 6667;
    $self->{post_interval}      //= 2;
    $self->{reconnect_interval} //= 3;

    my ($irc, $is_connect, $connector);
    $connector = sub {
        irc
            $self->{host},
            port       => $self->{port},
            key        => $self->{keyword},
            password   => $self->{password},
            nickname   => $self->{nickname},
            user       => $self->{user},
            interval   => $self->{post_interval},
            enable_ssl => $self->{enable_ssl},
            on_connect => sub {
                my ($con, $err) = @_;
                if (defined $err) {
                    warn "connect error: $err\n";
                    exit 1 unless $self->{reconnect_interval};
                    sleep $self->{reconnect_interval};
                    $con->disconnect('try reconnect');
                } else {
                    warn 'connect';
                    $is_connect = 1;
                }
            },
            on_disconnect => sub {
                warn 'disconnect';
                # XXX: bad hack...
                undef $irc->{client};
                undef $irc->{SEND_TIMER};
                undef $irc;
                $is_connect = 0;
                $irc = $connector->();
            },
            channels => {
                map { my $chan = $_; $chan = '#'.$chan unless $chan =~ /^#/;  ;($chan => +{}) } @{ $self->{join_channels} || [] },
            };
    };
    $irc = $connector->();
    $self->{irc} = $irc;

    AnySan->register_listener(
        echo => {
            cb => sub {
                my $receive = shift;
                $receive->{message} = decode_utf8 $receive->{message};
                $self->_invoke($receive);
            }
        }
    );

    $self;
}

sub on_message {
    my ($self, @jobs) = @_;
    while (my ($reg, $sub) = splice @jobs, 0, 2) {
        push @{ $self->_jobs }, [$reg, $sub];
    }
}

sub run {
    AnySan->run;
}

sub invoke_all { shift->{invoke_all} }

sub _jobs {
    shift->{_jobs} ||= [];
}

sub _invoke {
    my ($self, $receive) = @_;

    my $message = $receive->message; say $message;
    for my $job (@{ $self->_jobs }) {
        if (my @matches = $message =~ $job->[0]) {
            $job->[1]->($receive, @matches);
            return unless $self->invoke_all;
        }
    }
}

package # hide from pause
    AnySan::Receive;

use Encode qw/encode_utf8/;

sub reply {
    my ($self, $msg) = @_;
    $self->send_reply(encode_utf8 $msg);
}

1;
__END__

=encoding utf-8

=head1 NAME

UnazuSan - It's new $module

=head1 SYNOPSIS

    use UnazuSan;

=head1 DESCRIPTION

UnazuSan is ...

=head1 LICENSE

Copyright (C) Masayuki Matsuki.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Masayuki Matsuki E<lt>y.songmu@gmail.comE<gt>

=cut
