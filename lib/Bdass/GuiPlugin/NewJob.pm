package Bdass::GuiPlugin::NewJob;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractTable';
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Bdass::Model::DataSource;

=head1 NAME

Bdass::GuiPlugin::NewJob - New Job Table

=head1 SYNOPSIS

 use Bdass::GuiPlugin::NewJob;

=head1 DESCRIPTION

List of all Jobs ready for submission of an archive request.

=cut


=head1 METHODS

All the methods of L<CallBackery::GuiPlugin::AbstractTable> plus:

=cut

#has formCfg => sub {
#    my $self = shift;
#    my $db = $self->user->db;
#
#    return [
#    ]
#};

has dataSource => sub {
    my $self = shift;
    Bdass::Model::DataSource->new(app=>$self->app);
};

=head2 tableCfg


=cut

has tableCfg => sub {
    my $self = shift;
    return [
        {
            label => trm('System'),
            type => 'string',
            width => '2*',
            key => 'ckey',
            sortable => $self->true,
        },
        {
            label => trm('Path'),
            type => 'string',
            width => '6*',
            key => 'path',
            sortable => $self->true,
        },
        {
            label => trm('Created'),
            type => 'string',
            width => '2*',
            key => 'ts',
            sortable => $self->true,
        },
        {
            label => trm('Token'),
            type => 'string',
            width => '2*',
            key => 'token',
            sortable => $self->true,
        },
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
            name => 'newJobFormAdd',
            popupTitle => trm('New job'),
            set => {
                minHeight => 600,
                minWidth => 500
            },
            backend => {
                plugin => 'NewJobForm',
                config => {
                    type => 'add'
                }
            }
        }
    ];
};


sub getTableRowCount {
    my $self = shift;
    my $args = shift;
    my $rows;
    # todo async callbackery
    $self->dataSource->getArchiveCandidates->then(sub {
        my $data = shift;
        $rows = scalar @$data;
    })->wait;
    return $rows;
}

sub getTableData {
    my $self = shift;
    my $args = shift;
    my $data = [];
    $self->dataSource->getArchiveCandidates->then(sub {
        $self->log->info("#### GUGUGS ###");
        $data = shift;
    });
    my $sc = $args->{sortColumn} // 'ts';
    return [
        (sort { $a->{$sc} cmp $b->{$sc} } @$data)[
            $args->{firstRow} .. $args->{lastRow} 
        ]
    ];
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
