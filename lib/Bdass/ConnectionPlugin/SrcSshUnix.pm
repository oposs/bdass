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
use CallBackery::Exception qw(mkerror);

has buffer => sub {''};

sub checkHost ($self) {
    open my $remote, '-|', 'ssh', $self->url->host,
            '(stat --version;du --version;tar --version) 2>&1';
    my $out = join '', <$remote>;
    close ($remote);
    if ($out =~ m{
        stat\s\(GNU\scoreutils\)\s(\S+).+
        du\s\(GNU\scoreutils\)\s(\S+).+
        tar\s\(GNU\star\)\s(\S+)
    }xs) {
        $self->log->debug('CHECK - '.$self->url->host.' has all the tools');
        return {
            stat => $1,
            du => $2,
            tar => $3
        };
    }
    $self->log->error("ssh closed while returning '$out'");
    return undef;
}

# make sure tha ssh session does not go out of
# scope too early
my %sshCache;
my $sshId = 'a';

sub checkFolder ($self,$path,$token=undef) {
    my $sshCachKey = $sshId++;
    my $ssh = $sshCache{$sshCachKey} = Mojo::IOLoop::ReadWriteFork->new;
    my $promise = Mojo::Promise->new;
    my $buffer = '';
    # Emitted when the child completes
    $ssh->on(error => sub ($ssh,$error) { 
        $self->log->error("ssh died $error");
        delete $sshCache{$sshCachKey};
        $promise->reject($error);
    });
    my $token_file = defined $token 
        ? '/'.$self->tokenFilePrefix.$token.'.txt' : '';
    # Emitted when the child completes
    $ssh->on(close => sub ($ssh, $exit_value, $signal) { 
        $self->log->debug("close event exit $exit_value, signal $signal") if $exit_value or $signal;
        # if the right stuff is in the buffer we do not ask questions 
        if ($buffer =~ m{^(\d+)<>(.+)${token_file}\n$}){
            return $promise->resolve({
                ts => $1,
                path => $2
            });
        }
        delete $sshCache{$sshCachKey};
        if ($exit_value and $buffer =~ /no such file/i) {
            return $promise->reject(mkerror(3874,"The token file does not exist in the requested path."));
        }
        $self->log->error("ssh closed with signal $signal and exit value $exit_value while returning '$buffer'");
        return $promise->reject(mkerror(39484,"ssh closed unexpectedly"));
    });
    $ssh->on(read => sub ($ssh,$buff) {
        $buffer .= $buff;
    });
    $self->log->debug("start ssh to ".$self->url->host);
    $ssh->start({
        program => "ssh",
        program_args => [
            $self->url->host,
            'stat','-c"%Z<>%n"',
            $path.$token_file
        ],
        conduit => 'pipe',
        env => {
            $ENV{SSH_AUTH_SOCK} ? (SSH_AUTH_SOCK => $ENV{SSH_AUTH_SOCK}) :()
        }
    });
    return $promise;
}


sub sizeFolder ($self,$path) {
    my $sshCachKey = $sshId++;
    my $ssh = $sshCache{$sshCachKey} = Mojo::IOLoop::ReadWriteFork->new;
    my $promise = Mojo::Promise->new;
    my $buffer = '';
    # Emitted when the child completes
    $ssh->on(error => sub ($ssh,$error) { 
        $self->log->error("ssh died $error");
        $promise->reject($error);
        delete $sshCache{$sshCachKey};
    });
    # Emitted when the child completes
    $ssh->on(close => sub ($ssh, $exit_value, $signal) { 
        $self->log->debug("close event exit $exit_value, signal $signal");
        # if the right stuff is in the buffer we do not ask questions 
        if ($buffer =~ m{^(\d+)\s+}){
            return $promise->resolve({
                size => $1 * 1024
            });
        }
        delete $sshCache{$sshCachKey};
        if ($exit_value and $buffer =~ /no such file/i) {
            return $promise->reject(mkerror(3874,"The folder does not exit"));
        }
        $self->log->error("ssh closed with signal $signal and exit value $exit_value while returning '$buffer'");
        return $promise->reject(mkerror(39484,"ssh closed unexpectedly"));
    });
    $ssh->on(read => sub ($ssh,$buff) {
        $buffer .= $buff;
    });
    $self->log->debug("start ssh to ".$self->url->host);
    $ssh->start({
        program => "ssh",
        program_args => [
            $self->url->host,
            'du','-sk', $path
        ],
        conduit => 'pipe',
        env => {
            $ENV{SSH_AUTH_SOCK} ? (SSH_AUTH_SOCK => $ENV{SSH_AUTH_SOCK}) :()
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
