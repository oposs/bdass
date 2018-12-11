package Bdass::Model::DataSource;

use Mojo::Base -base,-signatures;
use Time::HiRes qw(gettimeofday);
use Mojo::Util qw(dumper);

=head1 NAME

Bdass::Model::DataSource - Data Source Management

=head1 SYNOPSIS

 use Bdass::Model::DataSource;
 my $src = Bdass::Model::DataSource->new;

=head1 DESCRIPTION

=cut

has 'app';
has log => sub { shift->app->log };
has cfg => sub {
    shift->app->config->cfgHash;
};


=head3 checkPath($key,$path,$token)

Returns the last update time for the given token (or path if there is no token specified). Returns a promise.

=cut

sub checkPath ($self,$key,$path,$token=undef) {
    my $plugin = $self->cfg->{CONNECTION}{$key}{plugin};
    return $plugin->checkFolder($path,$token)
}

=head3 checkConnections()

Verify the stat exists on all configured devices. Returns a promise.

=cut

sub checkConnections ($self) {
    my @work;
    my @data;
    for my $key (keys %{$self->cfg->{CONNECTION}}){
        push @work,$self->checkPath($key,'/')->then(sub ($data) {
            my $result = shift;
            push @data,$data;
            $self->app->log->debug($key." done");
            return 1;
        });
    }
    return Mojo::Promise->all(@work)->then(sub {
        return \@data;
    });
}

=head3 addArchiveJob ($self,$user,$server,$path)

Add an ArchiveJob request. Returns a promise.

=cut

sub addArchiveJob ($self,$args) {
    $self->checkPath($args->{server},$args->{path},$args->{user}->userToken)->then(sub ($data) {
        my $pro = Mojo::Promise->new;
        $args->{user}->mojoSqlDb->insert('job',{
            job_cbuser => $args->{user}->userId,
            job_server => $args->{server},
            job_note => $args->{note},
            job_src => $data->{path},
            job_token_ts => $data->{ts}
        },sub ($db,$error,$result) {
            if ($error){
                return $pro->reject($error);
            }
            if ($result and $result->last_insert_id){
                return $pro->resolve($result->last_insert_id);
            }
            return $pro->reject("failed to insert job");
        });
        return $pro;
    });
}

=head3 sizeNewJobs ($self)

Query the database for jobs not yet sized. 

=cut

sub sizeNewJobs ($self) {
    my $mainpro = Mojo::Promise->new;
    my $sql = $self->app->database->sql;

    $sql->db->select('job',undef,{
        job_js => 1
    },sub ($db,$error,$result) {
        if ($error){
            return $mainpro->reject($error);
        }
        return $mainpro->resolve($result->hashes);
    });

    return $mainpro->then(sub ($hashes) {
        my @jobs;

        for my $job (@{$hashes->to_array}) {

            my $plugin = $self->cfg->{CONNECTION}{$job->{job_server}}{plugin};
            my $pro = Mojo::Promise->new;

            my $where = { 
                job_id => $job->{job_id}
            };

            $sql->db->update('job',{
                job_js => 2
            },$where,sub ($db,$error,$result) {
                if ($error){
                    return $pro->reject($error);
                }
                return $pro->resolve($result);
            });
            
            push @jobs, $pro->then(sub {
                return $plugin->sizeFolder($job->{job_src})
            })->then( sub ($data) {
                my $subpro = Mojo::Promise->new;
                $sql->db->update('job',{
                    job_size => $data->{size},
                    job_js => 3
                },$where,sub ($db,$error,$result) {
                    if ($error){
                        return $subpro->reject($error);
                    }
                    return $subpro->resolve({
                        job_id => $job->{job_id},
                        job_size => $data->{size}
                    });
                });
                return $subpro;
            })->catch( sub ($err) {
                my $subpro = Mojo::Promise->new;
                $sql->db->update('job',{
                    job_js => 1
                },$where,sub ($db,$error,$result) {
                    if ($error){
                        return $subpro->reject($error);
                    }
                    return $subpro->reject($err);
                });
                return $subpro;
            });
        }
        return \@jobs;
    });
}

1;