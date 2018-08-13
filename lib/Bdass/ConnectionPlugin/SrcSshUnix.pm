package Bdass::ConnectionPlugin::SrcSshUnix;

use Mojo::Base qw(Bdass::ConnectionPlugin::base);

sub makeTransport {
    my $self = shift;
    my $dest = shift;
    my $ssh = Mojo::IOLoop::ReadWriteFork->new;

    # Emitted if something terrible happens
    $ssh->on(error => sub { 
        my ($fork, $error) = @_; 
        $self->log->error($error); 
    });

    # Emitted when the child completes
    $ssh->on(close => sub { 
        my ($fork, $exit_value, $signal) = @_;
    });
    # Start the application
    $ssh->start({
        program => "ssh",
        program_args => [$dest],
        conduit => 'pty',
        raw => 1,
        env => {}
    });
    $self->setPrompt();
    return $ssh;
};

has log => sub { shift->app->log };

sub run {
    my $self   = shift;
    local @ARGV = @_ if @_;
    GetOptions(\%opt,
            'verbose|v','cfgglob=s');
    
    my ($flavor,$dest) = @ARGV;

    if ($flavor ne 'ubuntu'){
        die "Sorry $flavor is not supported yet\n";
    }
    $self->destHost($dest);  
    $self->setPrompt('hello> ')->then(sub{
        $self->checkTransparency();
    })->wait;
    Mojo::IOLoop->start;
}

sub setPrompt {
    my $self = shift;
    my $promise = Mojo::Promise->new;
    my $prompt = shift;
    my $ssh = $self->ssh;
    my $buff = '';
    my $okCb;
    $okCb = sub {
        my ($fork, $buf) = @_;
        $buff .= $buf;
        warn dumper($buff);
        if ($buff =~ /$prompt/){
            $fork->unsubscribe(read=>$okCb);
            $self->log->info("prompt check successful");
            $promise->resolve();
        }
    };    
    $ssh->on(read=>$okCb);
    $ssh->write(qq{stty -echo\nPS1='${prompt}'\n});
    return $promise;
}

sub checkTransparency {;
    my $self = shift;
    my $promise = Mojo::Promise->new;
    my $send_ord = 0;
    my $buff = ''  ;
    my $ssh = $self->ssh;
    my $readCb;
    $readCb = sub {
        my ($fork, $buf) = @_;
        $buff .= $buf;
        #warn dumper($buff);
        # $self->log->debug("got >".dumper($buf));
        while ($buff =~ s/^.*?>(.)<\n//s){
            my $ord = ord($1);
            if ($ord != $send_ord){
                $self->log->error("expected chr($send_ord) got chr($ord)");
            }
            if ($ord == 255){
                $fork->unsubscribe(read=>$readCb);
                $self->log->info("com transparency check successful");
                $promise->resolve();
            }
            else {
                $fork->write('>'.chr(++$send_ord).'<'."\n");
            }
        }
    };
    $ssh->on(read => $readCb);
    $ssh->write("dd bs=4 count=256\n");
    $ssh->write('>'.chr($send_ord)."<\n");
    return $promise;
}
