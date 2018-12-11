package Bdass::ConnectionPlugin::base;

use Mojo::Base 'Mojo::EventEmitter', -signatures;
use Mojo::Promise;

=head1 NAME

Bdass::ConnectionPlugin::Base - abstract connection plugin

=head1 SYNOPSIS

 use Mojo::Base 'Bdass::ConnectionPugin::base';

=head1 DESCRIPTION

The Connection Plugin Base Class.

=head2 Properties

=head3 app

=cut

has 'app';

has log => sub {
    shift->app->log;
};

has 'name';
has 'app';
has 'url';
has 'connectionId';


has tokenFilePrefix => 'BDASS_';

=head3 checkHost($self)

verify that the tools we need are present on the server in question

=cut

sub checkHost ($self) {
    return 0
};

=head3 checkFolder($path,$token)

return a promise which resolves to a folder of the tokenFile is found 

=cut

sub checkFolder ($self,$path,$token) {
    return Mojo::Promise->new;
};

=head3 streamFolder

convert the content of the folder into a tar archive
return an event emitter with 'info','read' 'error' 'close' events

=cut

sub streamFolder ($self,$path) {
    return Mojo::EventEmitter->new;
}

=head3 sizeFolder ($self,$path)

calculate the size of the data stored in the folder

=cut

sub sizeFolder ($self,$path,$token) {
    return Mojo::Promise->new;
};

=head3 shellQuote($self,@args)

turn an array into a shell-resistant array for ssh

=cut

sub _shellQuote ($self,@args) {
    for (@args){
        s/'/'"'"'/g;
        s/\*/'*'/g;
        s/\?/'?'/g;
    }
    return join ' ', map {qq{'$_'}} @args;
}

1;