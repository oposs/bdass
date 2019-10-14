package Bdass::GuiPlugin::JobDecisionForm;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractForm', -signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use POSIX qw(strftime);
use Mojo::JSON qw(true false);
use String::Random;

=head1 NAME

Bdass::GuiPlugin::JobTriageForm - Job Triage Form

=head1 SYNOPSIS

 use Bdass::GuiPlugin::JobTriageForm;

=head1 DESCRIPTION

Use this form to decide on how to proceede with an archiving request.

=cut

=head1 METHODS

All the methods of L<CallBackery::GuiPlugin::AbstractForm> plus:

=cut

=head2 formCfg

Returns a Configuration Structure for the Job Entry Form.

=cut


has formCfg => sub {
    my $self = shift;
    my $db = $self->user->db;
    my $jsHid2Id = $self->app->jsHid2Id;
    my $con = {
        0 => 'Pick Action',
        $jsHid2Id->{approved} => 'Archiving Approved',
        $jsHid2Id->{denied} => 'Archiving Denied',
    };
    my $servers = [ map {
        { key => "$_",
          title => $con->{$_},
        }
    } sort keys %$con ];
    return [
        {
            widget => 'header',
            label => trm('Job Details'),
        },
        {
            key => 'job_id',
            widget => 'text',
            label => trm('Job ID'),
            set => {
                readOnly => true,
            },
        },
        {
            key => 'job_name',
            widget => 'text',
            label => trm('Archive Name'),
            set => {
                readOnly => true,
            },

        },
        {
            key => 'job_project',
            widget => 'text',
            label => trm('Project Name'),
            set => {
                readOnly => true,
            },
        },
        {
            key => 'job_server',
            widget => 'text',
            label => trm('Server'),
            set => {
                readOnly => true,
            },
        },
        {
            key => 'cbuser_login',
            widget => 'text',
            label => trm('User'),
            set => {
                readOnly => true,
            },
        },
        {
            key => 'job_group',
            widget => 'text',
            label => trm('Group'),
            set => {
                readOnly => true,
            },
        },
        {
            key => 'job_src',
            widget => 'text',
            label => trm('Path'),
            set => {
                readOnly => true,
            },
        },
        {
            key => 'job_size',
            widget => 'text',
            label => trm('Size'),
            set => {
                readOnly => true,
            },
        },
        {
            key => 'job_note',
            widget => 'textArea',
            label => trm('Note from Requestor'),
            set => {
                readOnly => true
            },
        },
        {
            widget => 'header',
            label => trm('Decision'),
        },
        {
            key => 'job_js',
            widget => 'selectBox',
            label => 'Decision',
            set => {
                required => true,
            },
            cfg => {
                structure => $servers,
            },
            validator => sub ($value,$field,$form) {
                if (not exists $con->{$value}) {
                    return trm("Pick a valid decision")
                }
                return undef;
            }
        },
        {
            key => 'job_dst',
            widget => 'text',
            set => {
                required => true,
            },
            label => trm('Destination Folder'),
            validator => sub ($value,$field,$form) {
                if (not $value =~ m{^/}) {
                    return trm("Destination folder must start with /");
                }
                if (not -d $value) {
                    return trm("Destination folder does not exist");
                }
                return undef;
            }
        },
        {
            key => 'job_decision',
            widget => 'textArea',
            set => {
                required => true,
            },
            label => trm('Note to Requestor'),
        },
    ];
};

has actionCfg => sub ($self) {
    my $handler = sub ($self,$form) {
        return $self->app->dataSource->recordDecision({
            user => $self->user,
            job => $form->{job_id},
            dst => $form->{job_dst},
            js => $form->{job_js},
            decision=> $form->{job_decision}
        })->then( sub ($data) {
            return {
                action => 'dataSaved',
                message => trm("Job Archiving Decision recorded."),
                title => trm("Job Update"),
            }
        });
    };

    return [
        {
            label => trm('Record Decision'),
            action => 'submit',
            key => 'save',
            actionHandler => $handler
        }
    ];
};

has checkAccess => sub ($self) {
    return $self->user->may('admin');
};

=head1 METHODS

All the methods of L<CallBackery::GuiPlugin::AbstractForm> plus:

=cut

sub db ($self) {
    $self->user->mojoSqlDb;
}

sub getAllFieldValues ($self,@args) {
    my $id = $args[0]->{selection}{job_id};
    my $jsHid2Id = $self->app->jsHid2Id;
    my $data = $self->db->select(
        ['job'
            => ['cbuser' => 'cbuser_id', 'job_cbuser'],
        ],
        [qw(job_id job_name job_project job_server job_group job_src job_dst job_size job_note job_js job_decision cbuser_login)],
        {job_id => $id, job_js => [$jsHid2Id->{sized},$jsHid2Id->{denied},$jsHid2Id->{approved}] })->hash;
    die mkerror(39483,"Only sized, denied and approved jobs can be decided upon")
        if not $data;
    # hash key in frontend must be a string
    $data->{job_js} = "".$data->{job_js};
    return $data;
}

1;



__END__

=head1 COPYRIGHT

Copyright (c) 2018 by OETIKER+PARTNER AG. All rights reserved.

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2018-04-12 oetiker 0.0 first version

=cut
