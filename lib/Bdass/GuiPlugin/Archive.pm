package Bdass::GuiPlugin::Archive;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractTable',-signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false);
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
    return [];
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
            label => trm('Reload'),
            action => 'submit',
            addToContextMenu => false,
            key => 'reload',
            actionHandler => sub {
                return {
                    action => 'reload'
                }
            }
        }
    ];
};

sub db ($self) {
    $self->user->mojoSqlDb;
}

sub getTableRowCount ($self,$args,@opts) {
    my $userFilter = $self->user->may('admin') ? undef : {
        job_cbuser => $self->user->userId
    };
    return ($self->db->select('job',[\'count(job_id) AS count'],$userFilter)->hash->{count});
}

sub getTableData ($self,$args,@opts) {
    my %SORT;
    my $userFilter = $self->user->may('admin') ? {
        js_hid => 'verified' }
    } : {
        job_cbuser => $self->user->userId,
        js_hid => 'verified' }
    };
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
        ['job.*','js_hid','cbuser_login'],$userFilter,\%SORT
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