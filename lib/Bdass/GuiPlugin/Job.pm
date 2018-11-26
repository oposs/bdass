package Bdass::GuiPlugin::Job;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractTable';
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);

=head1 NAME

Bdass::GuiPlugin::Job - Job Table

=head1 SYNOPSIS

 use Bdass::GuiPlugin::Job;

=head1 DESCRIPTION

The Job Table Gui.

=cut


=head1 METHODS

All the methods of L<CallBackery::GuiPlugin::AbstractTable> plus:

=cut

has formCfg => sub {
    my $self = shift;
    my $db = $self->user->db;

    return [
        
        {
            key => 'job_title',
            widget => 'text',
            label => 'Search',
            set => {
                placeholder => 'Job Title',
            },
        },
    ]
};

=head2 tableCfg


=cut

has tableCfg => sub {
    my $self = shift;
    return [
        {
            label => trm('Id'),
            type => 'number',
            width => '1*',
            key => 'job_id',
            sortable => $self->true,
            primary => $self->true
        },
        {
            label => trm('Src'),
            type => 'string',
            width => '6*',
            key => 'job_src',
            sortable => $self->true,
        },
        {
            label => trm('Dst'),
            type => 'string',
            width => '6*',
            key => 'job_dst',
            sortable => $self->true,
        },
        {
            label => trm('Created'),
            type => 'string',
            width => '2*',
            key => 'job_ts_created',
            sortable => $self->true,
        }
     ]
};

=head2 actionCfg

Only users who can write get any actions presented.

=cut

has actionCfg => sub {
    my $self = shift;
    return [] if $self->user and not $self->user->may('write');

    return [
        {
            label => trm('Create Job'),
            action => 'popup',
            addToContextMenu => $self->false,
            name => 'newJobAdd',
            popupTitle => trm('New job'),
            set => {
                minHeight => 500,
                minWidth => 800
            },
            backend => {
                plugin => 'NewJob',
                config => {
                    type => 'add'
                }
            }
        },
        # {
        #     action => 'separator'
        # },
        # {
        #     label => trm('Edit'),
        #     action => 'popup',
        #     addToContextMenu => $self->true,
        #     defaultAction => $self->true,
        #     name => 'jobFormEdit',
        #     popupTitle => trm('Edit job'),
        #     backend => {
        #         plugin => 'JobForm',
        #         config => {
        #             type => 'edit'
        #         }
        #     }
        # },
        # {
        #     label => trm('Delete'),
        #     action => 'submitVerify',
        #     addToContextMenu => $self->true,
        #     question => trm('Do you really want to delete the selected job '),
        #     key => 'delete',
        #     handler => sub {
        #         my $args = shift;
        #         my $id = $args->{selection}{job_id};
        #         die mkerror(4992,"You have to select a job first")
        #             if not $id;
        #         my $db = $self->user->db;
        #         if ($db->deleteData('job',$id) == 1){
        #             return {
        #                  action => 'reload',
        #             };
        #         }
        #         die mkerror(4993,"Faild to remove job $id");
        #         return {};
        #     }
        # }
    ];
};

sub dbh {
    shift->user->mojoSqlDb->dbh;
};

sub _getFilter {
    my $self = shift;
    my $search = shift;
    my $filter = '';
    if ( $search ){
        $filter = "WHERE job_title LIKE ".$self->dbh->quote('%'.$search);
    }
    return $filter;
}

sub getTableRowCount {
    my $self = shift;
    my $args = shift;
    my $filter = $self->_getFilter($args->{formData}{job_title});
    return ($self->dbh->selectrow_array("SELECT count(job_id) FROM job $filter"))[0];
}

sub getTableData {
    my $self = shift;
    my $args = shift;
    my $filter = $self->_getFilter($args->{formData}{job_title});
    my $SORT ='';
    if ($args->{sortColumn}){
        $SORT = 'ORDER BY '.$self->dbh->quote_identifier($args->{sortColumn});
        $SORT .= $args->{sortDesc} ? ' DESC' : ' ASC';
    }
    return $self->dbh->selectall_arrayref(<<"SQL",{Slice => {}}, $args->{lastRow}-$args->{firstRow}+1,$args->{firstRow});
SELECT *
FROM job
$filter
$SORT
LIMIT ? OFFSET ?
SQL
}

1;
__END__

=head1 COPYRIGHT

Copyright (c) 2018 by Tobias Oetiker. All rights reserved.

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2018-04-12 oetiker 0.0 first version

=cut
