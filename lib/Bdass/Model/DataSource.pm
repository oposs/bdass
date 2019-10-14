package Bdass::Model::DataSource;

use Mojo::Base -base,-signatures;
use Time::HiRes qw(gettimeofday);
use Mojo::Util qw(dumper);
use Mojo::JSON qw(decode_json);
use Mojo::File;
use Mojo::IOLoop::Stream;
use Bdass::Model::Mail;
use IPC::Open3;


=head1 NAME

Bdass::Model::DataSource - Data Source Management

=head1 SYNOPSIS

 use Bdass::Model::DataSource;
 my $src = Bdass::Model::DataSource->new;

=head1 DESCRIPTION

=cut

has 'app';

has log => sub ($self) {
    $self->app->log
};

has cfg => sub ($self) {
    $self->app->config->cfgHash;
};

has sql => sub ($self) {
    $self->app->database->sql
};

has jsHid2Id => sub ($self) {
    $self->app->jsHid2Id
};

has mail => sub ($self) { 
    Bdass::Model::Mail->new( app => $self->app );
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
                job_group => $args->{group},
                job_private => $args->{private},
                job_token => $args->{token},
                job_server => $args->{server},
                job_note => $args->{note},
                job_src => $data->{path},
                job_name => $args->{name},
                job_project => $args->{project}
            },sub ($db,$error,$result) {
                if ($error){
                    $tx = undef;
                    return $pro->reject($error);
                }
                if ($result and $result->last_insert_id){
                    return $self->recordHistory($db,{
                        job => $result->last_insert_id,
                        cbuser => $args->{user}->userId,
                        js => $self->jsHid2Id->{new},
                        note => "Job created"
                    })->then(sub {
                        $tx->commit;
                        return $pro->resolve("job recorded");
                    },sub ($error) {
                        $tx = undef;
                        return $pro->reject($error);
                    });
                };
                $tx = undef;
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
    return Mojo::Promise->new( sub ($resolve,$reject) {
        if (!$args->{user}->may('admin')){
            return $reject->("No Permission to grant/reject Jobs");
        }
        my $db = $self->sql->db;
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
            job_js => [@{$self->jsHid2Id}{qw(sized approved denied)}], # sized
        },sub ($db,$error,$result) {
            if ($error){
                $tx = undef;
                return $reject->("Updating job $args->{id}: $error");
            }
            $self->recordHistory($db,{
                job => $args->{job},
                cbuser => $args->{user}->userId,
                js => $args->{js},
                note => $args->{dst} . " - " .$args->{decision}
            })->then(sub ($ret) {
                $tx->commit;
                if ($args->{js} == $self->jsHid2Id->{approved}){
                    $self->mail->sendMail(
                        "job:".$args->{job},
                        "Archive Request $args->{job} has been approved",
                        "$args->{decision}\n\nYou will get a notification once archiving is complete."
                    );
                }
                elsif ($args->{js} == $self->jsHid2Id->{denied}){
                    $self->mail->sendMail(
                        "job:".$args->{job},
                        "Archive Request $args->{job} has been denied",
                        "$args->{decision}"
                    );
                }
                return $resolve->("new entry recorded");
            })->catch(sub ($error) {
                $tx = undef;
                return $reject->("recording history: $error");
            });
        });
    });
}

=head3 sizeNewJobs ($self)

Query the database for jobs not yet sized.

=cut

sub sizeNewJobs ($self) {
    my $mainpro = Mojo::Promise->new;
    my $jsHid2Id = $self->app->jsHid2Id;
    my $sql = $self->sql;
    $sql->db->select('job',undef,{
        job_js => $jsHid2Id->{new}
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
                job_id => $job->{job_id},
            };

            $sql->db->update('job',{
                job_js => $jsHid2Id->{sizing},
                job_ts_updated => time,
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
                    job_js => $jsHid2Id->{sized},
                },$where,sub ($db,$error,$result) {
                    if ($error){
                        return $subpro->reject($error);
                    }
                    return $subpro->resolve({
                        job_id => $job->{job_id},
                        job_name => $job->{job_name},
                        job_size => $data->{size},
                        job_ts_updated => time,
                    });
                });
                return $subpro;
            })->catch( sub ($err) {
                my $subpro = Mojo::Promise->new;
                $sql->db->update('job',{
                    job_js => $jsHid2Id->{new},
                    job_ts_updated => time,
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

=head3 transferData ($self)

Query the database for approved jobs.

=cut

sub transferData ($self) {
    my $mainpro = Mojo::Promise->new;
    my $jsHid2Id = $self->app->jsHid2Id;
    my $sql = $self->sql;
    $sql->db->select('job',undef,{
        job_js => $jsHid2Id->{approved}
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
                job_js => $jsHid2Id->{archiving},
                job_ts_updated => time,
            },$where,sub ($db,$error,$result) {
                if ($error){
                    return $pro->reject($error);
                }
                return $pro->resolve($result);
            });

            push @jobs, $pro->then(sub {
                return $plugin->streamFolder($job->{job_src})
            })->then( sub ($data) {
                my $subpro = Mojo::Promise->new;
                my $archive = $self->_jobToArchive($job);
                $self->log->debug("archiving job $job->{job_id}: $job->{job_src} -> $archive");
                open my $fh, "|- :raw", "zstd", "-", "-T","4","-f","-q","-o",
                    $archive
                    or die "opening job tar: $!";

                my $em = $plugin->streamFolder($job->{job_src});
                $em->on(error => sub ($em,$msg,@args) {
                    unlink $archive;
                    $subpro->reject("transferring job $job->{job_id}: $msg");
                });
                $em->on(read => sub ($em,$buff,@data) {
                    print $fh $buff;
                });
                $em->on(complete => sub ($em,@data) {
                    close($fh);
                    return $subpro->reject("closing job $job->{job_id}: $!")
                        if $!;
                    $self->updateJobStatus($job,'archived')->then(sub {
                        return $subpro->resolve($job);
                    },sub ($error) {
                        return $subpro->reject("recording history: $error");
                    });
                });
                return $subpro;
            })->catch( sub ($err) {
               return $self->updateJobStatus($job,'approved');
            });
        }
        return \@jobs;
    });
}

=head3 catalogArchives ($self)

Go through all the archives in 'archived' state, read them back and update the database in the process.

=cut

sub catalogArchives ($self) {
    return Mojo::Promise->new( sub ($resolve,$reject) {
        my $jsHid2Id = $self->app->jsHid2Id;
        my $sql = $self->sql;

        $sql->db->select('job',undef,{
            job_js => $jsHid2Id->{archived}
        },sub ($db,$error,$result) {
            if ($error){
                return $reject->($error);
            }
            $resolve->($result->hashes);
        });
    })->then(sub ($hashes) {
        my @jobs;
        for my $job (@{$hashes->to_array}) {
            push @jobs, Mojo::Promise->new(sub ($resolve,$reject) {
                my $archive = $self->_jobToArchive($job);
                $self->log->debug("cataloging job $archive");
                my $rfh = IO::Handle->new;
                my $efh = IO::Handle->new;

                my $pid = eval {
                    open3(undef, $rfh, $efh,
                        'tar',
                        '--use-compress-program=zstd',
                        '--list',
                        '--verbose',
                        '--quoting-style=escape',
                        '--file='.$archive
                    );
                };
                if ($@){
                    $reject->($@);
                }
                $self->log->debug("started tar");
                my $rst = Mojo::IOLoop::Stream->new($rfh);
                $rst->timeout(0);
                my $est = Mojo::IOLoop::Stream->new($efh);
                $est->timeout(0);

                $rst->on(close => sub ($st) {
                    $rst->stop;
                    $est->stop;
                    close($efh);
                    waitpid($pid,0);
                    my $ret = $?;
                    if ($ret == 0) {
                        $resolve->(1);
                    }
                    $reject->("cataloging $archive ended with exit code ($ret)");
                });

                $rst->on(error => sub ($st,$err) {
                    $rst->stop;
                    $est->stop;
                    close($rfh);
                    close($efh);
                    waitpid($pid,0);
                    my $ret = $?;
                    $reject->("error which parsing $archive: $err. ($ret)");
                });

                my $buffer = '';
                $rst->on(read => sub ($stream,$bytes) {
                    $buffer .= $bytes;
                    my @lines = split /[\n\r]+/, $buffer;
                    $buffer = pop @lines;
                    $self->parseAndStoreCatalog($job,\@lines);
                });

                $est->on(close => sub ($st) {
                    $est->stop;
                });

                $est->on(error => sub ($st,$err) {
                    $est->stop;
                    $reject->("error on STDERR while working on $archive: $err.");
                });

                $est->on(read => sub ($stream,$bytes) {
                    $self->log->error("cataloging $archive: $bytes");
                });
                $est->start;
                $rst->start;
            })->then(sub ($ret) {
                $self->_jobChown($job);
                $self->updateJobStatus($job,'verified');
                return $job;
            })->catch(sub ($err) {
                $self->log->error($err);
                $self->revertJobCatalog($job);
            });
        }
        return \@jobs;
    });
}

=head3 restoreArchives ($self)

Go through the task log and start restore tasks.

=cut

sub restoreArchives ($self) {
    return Mojo::Promise->new( sub ($resolve,$reject) {
        my $jsHid2Id = $self->app->jsHid2Id;
        my $sql = $self->app->database->sql;

        $sql->db->select('task',undef,{
            task_ts_started => undef,
        },sub ($db,$error,$result) {
            if ($error){
                return $reject->($error);
            }
            $resolve->($result->hashes);
        });
    })->then(sub ($hashes) {
        my @tasks;
        for my $task (@{$hashes->to_array}) {
            my $arguments = decode_json($task->{task_arguments});
            next unless $task->{task_call} eq 'restore';
            my $job = $self->sql->db->select(['job' => [
                'cbuser', 'cbuser_id' => 'job_cbuser'
            ]],undef,{
                job_id => $arguments->{job_id}
            })->hash;
            push @tasks, Mojo::Promise->new(sub ($resolve,$reject) {
                my $archive = $self->_jobToArchive($job);
                
                my $name = $job->{job_name};
                $name =~ s{[^=_a-z0-9]}{_}g;
                $name =  lc($job->{job_id}.'-'.$job->{cbuser_login}.'-'.$name);
                my $restore_dir = $self->cfg->{BACKEND}{restore_dir}.'/'.$name;
                $self->log->debug("restoring $archive to $restore_dir");
                if (-e $restore_dir){
                    return $reject->("archive restore target $restore_dir exists already");
                }
                mkdir $restore_dir,($job->{job_private} ? 0700 : 0750 );
                my $uid = getpwnam($job->{cbuser_login});
                my $gid = getgrnam($job->{job_group});
                chown $uid,$gid, $restore_dir;
                $self->sql->db->update('task',{
                    task_ts_started => time,
                    task_status => 'archive restoring'
                },
                {
                    task_id => $task->{task_id}
                });
                Mojo::IOLoop->subprocess(sub ($subprocess) {
                        chdir $restore_dir;
                        system 'tar',
                            '--use-compress-program=zstd',
                            '--group='.$job->{job_group},
                            '--owner='.$job->{cbuser_login},
                            '--extract',
                            '--file='.$archive;
                        if ($? != 0) {
                            $self->log->error("Extracting $archive failed.");

                            system 'rm', '-rf', $restore_dir;
                            $self->sql->db->update('task',{
                                task_ts_started => undef,
                                task_status => 'restore failed ... waiting for next round'
                            },
                            {
                                task_id => $task->{task_id}
                            });
                        }
                        return $?;
                    }, 
                    sub ($subprocess, $err, $ret) {
                        if ($err or $ret){
                            $self->_taskFail($task);
                            $reject->("archive restore failed");
                        }
                        $self->_taskSuccess($task,$restore_dir);
                        $resolve->({task => $task,job=>$job});
                    }
               );
            });
        }    
        return \@tasks;
    });
}

=head3 _taskFail ($self,$task)

record task failure

=cut

sub _taskFail ($self,$task) {
    $self->db->update('task',{
        task_ts_started => undef,
        task_ts_done => time,
        task_status => 'archive restore failed'
    },
    {
        task_id => $task->{task_id}
    });
    
    $self->mail->sendMail(
        "cbuser:".$task->{task_cbuser},
        "Archive Restore request $task->{task_id} failed",
        "see subject"
    );   
}

=head3 _taskSuccess ($self,$task,$path)

record task success

=cut

sub _taskSuccess ($self,$task,$path) {
    $self->sql->db->update('task',{
        task_ts_done => time,
        task_status => 'archive restore successful'
    },
    {
        task_id => $task->{task_id}
    });
    $self->mail->sendMail(
        "cbuser:".$task->{task_cbuser},
        "Archive Restore request $task->{task_id} is complete",
        "You can find your restored files in $path"
    );   
}

=head3 _jobToArchive ($self,$job)

returns the archive path

=cut

sub _jobToArchive ($self,$job) {
    my $name = "$job->{job_id}-$job->{job_project}-$job->{job_name}";
    $name =~ s{[^=_a-z0-9]+}{_}g;
    return $job->{job_dst}."/".$name.'.tar.zst';
}

=head3 _jobChown ($self,$job)

chown job according to job settings.

=cut

sub _jobChown ($self,$job) {
    my $user = $self->sql->db->select('cbuser','cbuser_login',{
        cbuser_id => $job->{job_cbuser}
    })->hash->{cbuser_login};
    my $group = $job->{job_group};
    my $uid = getpwnam($user);
    my $gid = getgrnam($group);
    chown $uid,$gid,$self->_jobToArchive($job);
}

=head3 recordHistory ($self,$job,$user,$js,$desc)

Update history log

=cut

sub recordHistory ($self,$db,$args) {
    $self->log->debug("start record");
    my $pro = Mojo::Promise->new;
    $db->insert('history',{
        history_job => $args->{job},
        history_cbuser => $args->{cbuser},
        history_ts => time,
        history_js => $args->{js},
        history_note => $args->{note}
    },sub ($db,$error,$result) {
        if ($error){
            $self->log->error("recordDecision: $error");
            return $pro->reject("error: ".$error);
        }
        $self->log->debug("recorded");
        return $pro->resolve("decision recorded");
    });
    return $pro;
}

=head3 updateJobStatus ($self,$job,$status)

update job status returns promise

=cut

sub updateJobStatus ($self,$job,$status) {
    my $jsHid2Id = $self->app->jsHid2Id;
    my $pro = Mojo::Promise->new;
    $self->sql->db->update('job',{
        job_js => $jsHid2Id->{$status}
    }, {
        job_id => $job->{job_id}
    },sub ($db,$error,$result) {
        if ($error){
            return $pro->reject("error: ".$error);
        }
        return $pro->resolve("status updated");
    });
    return $pro;
}

=head3 revertJobCatalog ($self,$job)

update job status, returns promise.

=cut

sub revertJobCatalog ($self,$job) {
    $self->updateJobStatus($job,'archived')->then(sub {
        my $pro = Mojo::Promise->new;
        $self->sql->db->delete('file',{
            file_job => $job->{job_id}
        },sub ($db,$error,$result) {
            if ($error){
                return $pro->reject("error: ".$error);
            }
            return $pro->reject("catalog reverted for $job->{job_id}");
        });
        return $pro;
    });
}

=head3 parseAndStoreCatalog($job,$linesArray)

update catalog database. runs sync

=cut

sub parseAndStoreCatalog ($self,$job,$linesArray) {
    my $db = $self->sql->db;
    my $tx = $db->begin;
    for my $line (@$linesArray) {
        my %data;
        @data{qw(
            file_perm
            file_owner
            file_size
            file_date
            file_time
            file_name)
        } = split /\s+/, $line;
        next if (delete $data{file_perm}) =~ /^d/;
        $data{file_job} = $job->{job_id};
        $data{file_date} = $data{file_date}
            .' '
            .(delete $data{file_time});
        $db->insert('file',\%data);
    }
    $tx->commit;
}

1;
