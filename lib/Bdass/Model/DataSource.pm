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

=head3 addArchiveJob ($self,{server,path,token})

Add an ArchiveJob request. Returns a promise.

=cut

sub addArchiveJob ($self,$args) {
    $self->checkPath($args->{server},$args->{path},$args->{token})->then(
        sub ($data) {
            my $db = $args->{user}->mojoSqlDb;
            my $tx = $db->begin;
            my $pro = Mojo::Promise->new;
            $db->insert('job',{
                job_cbuser => $args->{user}->userId,
                job_token => $args->{token},
                job_server => $args->{server},
                job_note => $args->{note},
                job_src => $data->{path},
            },sub ($db,$error,$result) {
                if ($error){
                    return $pro->reject($error);
                }
                if ($result and $result->last_insert_id){
                    return $self->recordHistory({
                        db => $db,
                        job => $result->last_insert_id,
                        cbuser => $args->{user}->userId,
                        js => 1,
                        note => "Job created"
                    })->then(sub {
                        $tx->commit;
                        return $pro->resolve("job recorded");
                    },sub ($error) {
                        return $pro->reject($error);
                    });
                };
                return $pro->reject("Failed to insert Job");
            });
            return $pro;
        }
    );
}

=head3 recordDecision ($self,$args)

Record decision on archive job

=cut

sub recordDecision ($self,$args) {
    my $pro = Mojo::Promise->new;

    if (!$args->{user}->may('admin')){
        return $pro->reject("No Permission to grant/reject Jobs");
    }
    my $db = $args->{user}->mojoSqlDb;
    my $tx = $db->begin;
    $db->update('job',
    {
        job_js => $args->{js},
        job_decision => $args->{decision},
        job_ts_updated => time,
        job_dst => $args->{dst}
    },
    {
        job_id => $args->{job},
        job_js => [3,4,8], # sized
    },sub ($db,$error,$result) {
        if ($error){
            return $pro->reject("Updating job $args->{id}: $error");
        }
        $self->recordHistory({
            db => $db,
            job => $args->{job},
            cbuser => $args->{user}->userId,
            js => $args->{js},
            note => $args->{dst} . " - " .$args->{decision}
        })->then(sub {
            $tx->commit;
            return $pro->resolve("new entry recorded");
        },sub ($error) {
            return $pro->reject("recording history: $error");
        });
    });
    return $pro;
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

sub transferData ($self) {
    my $mainpro = Mojo::Promise->new;
    my $sql = $self->app->database->sql;

    $sql->db->select('job',undef,{
        job_js => 4
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
            my $sum = 0;
            my $where = { 
                job_id => $job->{job_id}
            };

            $sql->db->update('job',{
                job_js => 5
            },$where,sub ($db,$error,$result) {
                if ($error){
                    return $pro->reject($error);
                }
                return $pro->resolve($result);
            });
            
            push @jobs, $pro->then(sub {
                my $subpro = Mojo::Promise->new;
                open my $fh, "> :raw", $job->{job_dst}."/job_".$job->{job_id}.".tar" 
                    or die "opening job tar: $!";
                my $em = $plugin->streamFolder($job->{job_src});
                $em->on(error => sub ($em,@msgs) {
                    $subpro->reject(@msgs);
                });
                $em->on(read => sub ($em,@data) {
                    $sum += length($data[0]);
                    print $fh $data[0] or return $subpro->reject($!);
                });
                $em->on(complete => sub ($em,@data) {
                    my $db = $sql->db;
                    my $tx = $db->begin;
                    $sql->db->update('job',{
                        job_js => 6
                    },$where,sub ($db,$error,$result) {
                        if ($error){
                            return $subpro->reject($error);
                        }
                        my $note = "Transfer $job->{job_server} complete $sum Bytes";
                        $self->recordHistory({
                            db => $db,
                            job => $job->{job_id},
                            js => 6,
                            note => $note
                        })->then(sub {
                            close($fh) or return $subpro->reject($!);
                            $tx->commit;
                            return $subpro->resolve($note);
                        },sub ($error) {
                            return $subpro->reject("recording history: $error");
                        });
                    });
                });
                return $subpro;
            })->catch( sub ($err) {
                my $subpro = Mojo::Promise->new;
                $sql->db->update('job',{
                    job_js => 4
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

=head3 recordHistory ($self,$job,$user,$js,$desc)

Update history log

=cut

sub recordHistory ($self,$args) {
    $self->log->debug("start record");
    my $pro = Mojo::Promise->new;
    $args->{db}->insert('history',{
        history_job => $args->{job},
        history_cbuser => $args->{cbuser},
        history_ts => time,
        history_js => $args->{js},
        history_note => $args->{note}
    },sub ($db,$error,$result) {
        if ($error){
            return $pro->reject($error);
        }
        return $pro->resolve("decision recorded");
    });
    return $pro;
}

1;