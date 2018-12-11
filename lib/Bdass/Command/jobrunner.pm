package Bdass::Command::jobrunner;

=name NAME

Bdass::Command::jobrunner - BDass jobrunner

=name SYNOPSIS

 ./bdass.pl jobrunner

=name DESCRIPTION

run jobs found in the job table. Depending on their state the size of the job will be calculated or the job will be streamed to the archive server.

=cut

use Mojo::Base 'Mojolicious::Command', -signatures;
use Mojo::IOLoop::ReadWriteFork;
use Mojo::Util qw(dumper);
use Mojo::Promise;
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
    my $data = Bdass::Model::DataSource->new(app=>$self->app);
    $data->sizeNewJobs->then(sub ($jobs) {
        my @allJobs;
        for my $jp (@$jobs){
            push @allJobs, $jp->then(sub ($job) {
                $self->app->log->debug("Job $job->{job_id} -> $job->{job_size}");
                return undef;
            })->catch(sub ($err) {
                $self->app->log->error("sub ".$err);
                return undef;
            });
        }
        return @allJobs ? Mojo::Promise->all(@allJobs) : undef;
    })->catch(sub ($err) {
        $self->app->log->error("big ".$err);
    })->wait;
}

1;