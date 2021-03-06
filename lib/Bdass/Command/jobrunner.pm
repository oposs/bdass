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

has cfg => sub { shift->app->config->cfgHash };

has dataSource => sub ($self) { 
    Bdass::Model::DataSource->new( app => $self->app );
};

has mail => sub ($self) { 
    $self->dataSource->mail;
};

sub sizeJobs ($self,$jobs) {
    my @allJobs;
    for my $jp (@$jobs){
        push @allJobs, $jp->then(sub ($job) {
            $self->log->debug("Job $job->{job_id} $job->{job_name} -> $job->{job_size}");
            $self->mail->sendMail($self->cfg->{BACKEND}{admin_email},"Archive Job $job->{job_id} $job->{job_name} ready for Decision","see subject");
            return undef;
        })->catch(sub ($err) {
            $self->log->error("size-sub-error ".$err);
            return undef;
        });
    }
    return @allJobs ? Mojo::Promise->all(@allJobs) : undef;
}

sub transferJobs ($self,$jobs) {
    my @allJobs;
    for my $jp (@$jobs){
        push @allJobs, $jp->then(sub ($job) {
            $self->log->debug("Job $job->{job_id} $job->{job_name} archived");
            return undef;
        })->catch(sub ($err) {
            $self->log->error("transfer-sub ".$err);
            return undef;
        });
    }
    return @allJobs ? Mojo::Promise->all(@allJobs) : undef;
};

sub catalogingArchives ($self,$jobs) {
    my @allJobs;
    for my $jp (@$jobs){
        push @allJobs, $jp->then(sub ($job) {
            $self->log->debug("Job $job->{job_id} $job->{job_name} verified");
            $self->mail->sendMail("job:".$job->{job_id},"Archive Job $job->{job_id} $job->{job_name} has been archived and verified","see subject");
            return undef;
        })->catch(sub ($err) {
            $self->log->error("catalog-sub ".$err);
            return undef;
        });
    }
    return @allJobs ? Mojo::Promise->all(@allJobs) : undef;
};
sub restoreTaks ($self,$tasks) {
    my @allTasks;
    for my $ta (@$tasks){
        push @allTasks, $ta->then(sub ($task) {
            return undef;
        })->catch(sub ($err) {
            $self->log->error("restore-task-sub ".$err);
            return undef;
        });
    }
    return @allTasks ? Mojo::Promise->all(@allTasks) : undef;
};

sub run {
    my $self   = shift;
    local @ARGV = @_ if @_;
    GetOptions(\%opt,
            'verbose|v');
    my $data = Bdass::Model::DataSource->new(app=>$self->app);
    Mojo::Promise->all(
        $data->sizeNewJobs->then(sub ($jobs) { $self->sizeJobs($jobs)} ),
        $data->transferData->then(sub ($jobs) { $self->transferJobs($jobs) }),
        $data->catalogArchives->then(sub ($jobs) { 
            $self->catalogingArchives($jobs) 
        }),
        $data->restoreArchives->then(sub ($tasks) { 
            $self->restoreTaks($tasks) 
        }),
    )->then(sub {
        $self->app->log->info("DONE");
    })->catch(sub ($error) {
        $self->app->log->error($error);
    })->wait;
}


1;