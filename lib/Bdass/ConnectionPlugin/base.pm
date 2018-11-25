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
has 'folderList';


has tokenFilePrefix => 'BDASS_';


=head3 listFolders()

return a promise which resolves to a list of folders if it is happy

=cut

sub listFolders ($self) {
    return Mojo::Promise->new;
};

=head3 streamFolder

convert the content of the folder into a tar archive
return an event emitter with 'info','read' 'error' 'close' events

=cut

sub streamFolder ($self) {
    return Mojo::EventEmitter->new;
}


sub _shellQuote ($self,@args) {
    for (@args){
        s/'/'"'"'/g;
        s/\*/'*'/g;
        s/\?/'?'/g;
    }
    return join ' ', map {qq{'$_'}} @args;
}

1;