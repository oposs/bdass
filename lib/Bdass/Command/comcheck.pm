package Bdass::Command::comcheck;

=name NAME

Bdass::Command::com-test - BDass communication test

=name SYNOPSIS

 ./bdass.pl comcheck remoteHostKey

=name DESCRIPTION

connect to remote hosts and find repos

=cut

use Mojo::Base 'Mojolicious::Command', -signatures;
use Mojo::IOLoop::ReadWriteFork;
use Mojo::Util qw(dumper);
use Bdass::Model::DataSource;

use Getopt::Long;

has description => <<'EOF';
Query remote hosts to find archiving candidates
EOF

has usage => <<"EOF";
usage: $0 comcheck 
EOF
my %opt;

has log => sub { shift->app->log };

has cfg => sub { shift->app->config->cfgHash->{CONNECTION} };

sub run {
    my $self   = shift;
    local @ARGV = @_ if @_;
    GetOptions(\%opt,
            'verbose|v');
    my @work;
    my @data;
    my $data = Bdass::Model::DataSource->new(app=>$self->app);
    $data->getArchiveCandidates->then(sub {
        my $data = shift;
        $self->app->log->info(dumper $data);
    })->wait;
    $self->app->log->info("all done");
}

1;