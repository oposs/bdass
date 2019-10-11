package Bdass::GuiPlugin::Task;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractTable',-signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false);
use POSIX qw(strftime);


=head1 NAME

Bdass::GuiPlugin::Task - Task Table

=head1 SYNOPSIS

 use Bdass::GuiPlugin::Task;

=head1 DESCRIPTION

The Task Table Gui.

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
            key => 'task_id',
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
            label => trm('Call'),
            type => 'string',
            width => '2*',
            key => 'task_call',
            sortable => true,
        },
        {
            label => trm('Status'),
            type => 'string',
            width => '2*',
            key => 'task_status',
            sortable => true,
        },
        {
            label => trm('Created'),
            type => 'date',
            format => 'yyyy-MM-dd HH:mm:ss Z',
            width => '3*',
            key => 'v',
            sortable => true,
        },
        {
            label => trm('Started'),
            type => 'date',
            format => 'yyyy-MM-dd HH:mm:ss Z',
            width => '3*',
            key => 'task_ts_started',
            sortable => true,
        },
        {
            label => trm('Done'),
            type => 'date',
            format => 'yyyy-MM-dd HH:mm:ss Z',
            width => '3*',
            key => 'task_ts_done',
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

has userFilter => sub ($self) {
    my $userFilter = {
    };
    if (not $self->user->may('admin')){
        $userFilter->{task_cbuser}  = $self->user->userId;
    };
};

sub getTableRowCount ($self,$args,@opts) {
    return ($self->db->select('task',[\'count(task_id) AS count'],$self->userFilter)->hash->{count});
}

sub getTableData ($self,$args,@opts) {
    my %SORT;
    if ($args->{sortColumn}){
        $SORT{order_by} = {
            ($args->{sortDesc} ? '-desc' : '-asc')
             => $args->{sortColumn}
        };
    }

    $SORT{limit} = $args->{lastRow}-$args->{firstRow}+1;
    $SORT{offset} = $args->{firstRow};

    my $data = $self->db->select(
        ['task'
            => ['cbuser' => 'cbuser_id', 'task_cbuser'],
        ],
        ['task.*','cbuser_login'],$self->userFilter,\%SORT
    )->hashes->each(sub ($el,$id) {
        $el->{'task_ts_'.$_} *= 1000 for qw(created started done);
    })->to_array;
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
