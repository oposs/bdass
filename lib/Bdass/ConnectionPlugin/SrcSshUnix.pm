package Bdass::ConnectionPlugin::SrcSshUnix;

=head1 NAME

Bdass::ConnectionPlugin::Base - abstract connection plugin

=head1 SYNOPSIS

 use Bdass::ConnectionPlugin::SrcSshUnix;


=head1 DESCRIPTION

The Ssh Connection Plugin Class

=cut

use Mojo::Base qw(Bdass::ConnectionPlugin::base -signatures);
use Mojo::IOLoop::ReadWriteFork;
use Mojo::Util qw(dumper);

has buffer => sub {''};

has '_transport';

has delimiter => sub {'>>>>kjlasdfasdfasdfasdf89079ikhjkalsdjhfsdf<<<<' 
};


sub sshTransport ($self) {
    if (not defined $self->_transport){
        my $ssh = Mojo::IOLoop::ReadWriteFork->new;

        # Emitted when the child completes
        $ssh->on(error => sub { 
            my ($ssh, $error) = @_;
            $self->log->error("ssh died $error");
            $ssh = undef;
        });
        # Emitted when the child completes
        $ssh->on(close => sub { 
            my ($ssh, $exit_value, $signal) = @_;
            $self->log->info("ssh closed $exit_value/$signal");
            $ssh = undef;
            #   if ($signal > ???){
            #      $self->ssh($self->makeTransport);
            #   }
        });
        $ssh->on(read => sub {
            my ($ssh, $buff) = @_;
            # $self->log->debug($self->name.": got >".$buff);
            $self->buffer($self->buffer.$buff);
            $self->emit('gotData');
        });
        # Start the application
        $ssh->start({
            program => "ssh",
            program_args => [$self->url->host,'-T'],
            env => {
                SSH_AUTH_SOCK => $ENV{SSH_AUTH_SOCK}
            }
        });
        $self->log->debug($self->name.": start ssh to ".$self->url->host);
        $self->_transport($ssh);
    }
    return $self->_transport;
};

sub listFolders ($self) {
    my $delimiter = $self->delimiter;
    my $prefix = $self->tokenFilePrefix;
    my $promise = Mojo::Promise->new;
    $self->log->debug($self->name.": stat");
    $self->sshTransport->write("stat -c'>//>%Z<>%n<//<' 2>&1 ".
        $self->_shellQuote(
            map { $_ .'/'.$prefix.'*.txt' } @{$self->folderList}
        )
    .";echo '$delimiter'\n");
    my @list;
    $self->on('gotData',sub {
        my $self = shift;
        my $buffer = $self->buffer;
        while ($buffer =~ s[.*?>//>(\d+)<>(.+?)/${prefix}(.+?)\.txt<//<\n][]s) {
            push @list, { 
                ckey => $self->connectionId, 
                ts => $1, 
                path => $2, 
                token => $3
            };
        }
        $self->buffer($buffer);
        if ($buffer =~ s[.*$delimiter\n][]s){
            $self->buffer($buffer);
            $self->unsubscribe('gotData');
            $promise->resolve(\@list);
        }
    });
    return $promise;
}

1;



__END__

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2018-11-20 oetiker 0.0 first version

=cut
