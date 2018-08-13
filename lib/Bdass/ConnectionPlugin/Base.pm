package Bdass::ConnectionPlugin::Base;

use Mojo::IOLoop::ReadWriteFork;
use Mojo::Util qw(dumper);
use Mojo::Promise;

=head1 NAME

Bdass::ConnectionPlugin::Base - abstract connection plugin

=head1 SYNOPSIS

 use Mojo::Base 'Bdass::ConnectionPugin::Base';

=head1 DESCRIPTION

The Connection Plugin Base Class.

=cut

has 'app';


has type => sub {
    die "plugin must specify its type";
};

has tokenFile => 'BDASS_TOKEN.txt';

=head2 target

which machine are we talking to ?

=cut

has 'target';

=head2 listFolders

return a list of folders which could be archived

=cut

sub listFolders {
    my $self = shift;
    return Mojo::Promise->new;
};

=head2 streamFolder

convert the content of the folder to a configurable archive format
return an eventemitter with 'read' 'error' 'close' events

=cut

sub {
    my $self = shift;
    return Mojo::EventEmitter->new;
};

sub 
1;