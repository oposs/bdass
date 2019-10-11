package Bdass::GuiPlugin::File;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractTable',-signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false);
use POSIX qw(strftime);


=head1 NAME

Bdass::GuiPlugin::File - File Table

=head1 SYNOPSIS

 use Bdass::GuiPlugin::File;

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
            label => trm('Archive Id'),
            type => 'string',
            width => '2*',
            key => 'file_job',
            sortable => false,
        },
        {
            label => trm('Archive Name'),
            type => 'string',
            width => '2*',
            key => 'job_name',
            sortable => false,
        },
        {
            label => trm('Archive Owner'),
            type => 'string',
            width => '2*',
            key => 'cbuser_login',
            sortable => false,
        },
        {
            label => trm('File Name'),
            type => 'string',
            width => '2*',
            key => 'file_name',
            sortable => false,
        },
        {
            label => trm('File Date'),
            type => 'string',
            width => '1*',
            key => 'file_date',
            type => 'date',
            format => 'yyyy-MM-dd HH:mm:ss Z',
            width => '3*',
            sortable => false,
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
            key => 'file_size',
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
    ];
};

sub db ($self) {
    $self->user->mojoSqlDb;
}

sub userFilter ($self,$query) {
    my $userFilter = {};
    if (not $self->user->may('admin')){
        $userFilter->{-or} = [
            job_cbuser  => $self->user->userId,
            -and => [
                -not_bool => 'job_private',
                job_group   => [ keys %{$self->user->userInfo->{groups}}]
            ]
        ]
    }
 
    if ($query) {
        my @query = split /\s+/, $query;
        $userFilter->{file} = { 
            -match => $query
        }
    }
};

sub getTableRowCount ($self,$args,@opts) {
    my $query = $args->{formData}{query};
    return ($self->db->select('file',[\'count(*) AS count'],$self->userFilter($query))->hash->{count});
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
        ['file'
            => ['job' => 'job_id','file_job']
            => ['cbuser' => 'cbuser_id', 'job_cbuser'],
        ],
        ['file.*','job.*','cbuser_login'],$self->userFilter($query),\%SORT
    )->hashes->each(sub ($el,$id) {
        $el->{file_size} = int($el->{file_size});
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
