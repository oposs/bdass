package Bdass::GuiPlugin::Archive;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractTable',-signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false encode_json);
use POSIX qw(strftime);


=head1 NAME

Bdass::GuiPlugin::Archive - Archive Table

=head1 SYNOPSIS

 use Bdass::GuiPlugin::Archive;

=head1 DESCRIPTION

The Job Table Gui.

=cut


=head1 METHODS

All the methods of L<CallBackery::GuiPlugin::AbstractTable> plus:

=cut

has formCfg => sub ($self) {
    return [
         {
            key => 'query',
            widget => 'text',
            set => {
                placeholder => trm('Search ...')
            },
        },
    ];
};

=head2 tableCfg


=cut

has tableCfg => sub ($self) {
    return [
        {
            label => trm('Id'),
            type => 'number',
            width => '1*',
            key => 'job_id',
            sortable => true,
            primary => true,
        },
        (
            $self->user->may('admin')
            ?  {
                label => trm('User'),
                type => 'text',
                width => '2*',
                key => 'cbuser_login',
                sortable => true,
                primary => true,
            }
            : ()
        ),
        {
            label => trm('Name'),
            type => 'string',
            width => '2*',
            key => 'job_name',
            sortable => true,
        },
        {
            label => trm('Project'),
            type => 'string',
            width => '2*',
            key => 'job_project',
            sortable => true,
        },
        {
            label => trm('Group'),
            type => 'string',
            width => '2*',
            key => 'job_group',
            sortable => true,
        },
        {
            label => trm('Size'),
            type => 'num',
            format => {
                unitPrefix => 'metric',
                maximumFractionDigits => 2,
                postfix => 'Byte',
                locale => 'en'
            },
            width => '1*',
            key => 'job_size',
            sortable => true,
        },
        {
            label => trm('Server'),
            type => 'text',
            width => '2*',
            key => 'job_server',
            sortable => true,
        },
        {
            label => trm('Src'),
            type => 'string',
            width => '4*',
            key => 'job_src',
            sortable => true,
        },
        {
            label => trm('Dst'),
            type => 'string',
            width => '4*',
            key => 'job_dst',
            sortable => true,
        },
        {
            label => trm('Note'),
            type => 'string',
            width => '4*',
            key => 'job_note',
            sortable => true,
        },
        {
            label => trm('Verified'),
            type => 'date',
            format => 'yyyy-MM-dd HH:mm:ss Z',
            width => '3*',
            key => 'job_ts_updated',
            sortable => true,
        }
     ]
};

=head2 actionCfg

Only users who can write get any actions presented.

=cut

has actionCfg => sub ($self) {
    return [
        {
            label => trm('Search'),
            action => 'submit',
            addToContextMenu => false,
            key => 'search',
            actionHandler => sub {
                return {
                    action => 'reload'
                }
            }
        },
        {
            label => trm('Restore'),
            action => 'submit',
            addToContextMenu => true,
            key => 'restore',
            actionHandler => sub ($self,$args) {
                my $job = $self->db->select('job',undef,{
                    job_id => $args->{formData}{job_id},
                    $self->userFilter
                })->result->hash 
                or die mkerror(3948,"Permission denied");

                $self->db->insert('task',{
                    task_cbuser => $self->user->userId,
                    task_call => 'restore',
                    task_arguments => encode_json({
                        job_id => $job->{job_id},
                    }),
                    tast_status => 'waiting for execution'
                });
                return {
                    action => 'dataSaved',
                    message => trm("Restore scheduled. Will send email once restore is complete."),
                    title => trm("Restore Archive"),
                }
            }
        },
    ];
};

sub db ($self) {
    $self->user->mojoSqlDb;
}

sub userFilter ($self,$query) {
    my $userFilter = {
        js_hid => 'verified'
    };
    if (not $self->user->may('admin')){
        $userFilter->{-or} = [
            job_cbuser  => $self->user->userId,
            -and => [
                -not_bool => 'job_private'
                job_group   => [ keys %{$self->user->userInfo->{groups}}]
            ]
        ]
    }
    };
    if ($query) {
        my @query = split /\s+/, $query;
        $userFilter->{-and} = [
            map {
                'job_name || job_project'  => { 
                    -like => '%'.$_.'%'
                }, @query
            },
        ]
    }
};

sub getTableRowCount ($self,$args,@opts) {
    my $query = $args->{formData}{query};
    return ($self->db->select('job',[\'count(job_id) AS count'],$self->userFilter($query))->hash->{count});
}

sub getTableData ($self,$args,@opts) {
    my %SORT;
    my $query = $args->{formData}{query};

    if ($args->{sortColumn}){
        $SORT{order_by} = {
            ($args->{sortDesc} ? '-desc' : '-asc')
             => $args->{sortColumn}
        };
    }

    $SORT{limit} = $args->{lastRow}-$args->{firstRow}+1;
    $SORT{offset} = $args->{firstRow};

    my $data = $self->db->select(
        ['job'
            => ['js' => 'js_id','job_js']
            => ['cbuser' => 'cbuser_id', 'job_cbuser'],
        ],
        ['job.*','js_hid','cbuser_login'],$self->userFilter($query),\%SORT
    )->hashes->each(sub ($el,$id) {
        $el->{job_ts_created} = $el->{job_ts_created}*1000;
    })->to_array;
    return $data;
}

1;
__END__

=head1 COPYRIGHT

Copyright (c) 2019 by OETIKER+PARTNER AG. All rights reserved.

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2019-10-03 oetiker 0.0 first version

=cut
