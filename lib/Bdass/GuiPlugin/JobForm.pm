package Bdass::GuiPlugin::JobForm;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractForm', -signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use POSIX qw(strftime);
use Mojo::JSON qw(true false);
use Bdass::ConnectionPlugin::base;

=head1 NAME

Bdass::GuiPlugin::JobForm - Job Edit Form

=head1 SYNOPSIS

 use Bdass::GuiPlugin::NewJobForm;

=head1 DESCRIPTION

Use this form to submit a job for archiving.

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
    my $con = $self->app->config->cfgHash->{CONNECTION};
    my $servers = [ map {
        { key => $_,
          title => $con->{$_}{plugin}->name,
        }
    } keys %$con ];

    return [
        {
            widget => 'header',
            label => trm('Archive Job Creation'),
            note => trm('In order to register a folder for archiving, you have to prove that you have write access to it. You do this by creating archive token file in the folder you want to get archived. Every user has a unique archive token filename. You find yours on the line below.'),
        },

        {
            key => 'token',
            widget => 'text',
            note => trm(''),
            label => trm('Token File'),
            set => {
                readOnly => true,
            },
            getter => sub ($self) {
                return Bdass::ConnectionPlugin::base->new->tokenFilePrefix
                    . $self->user->userToken. '.txt',
            }        
        },
        {
            key => 'server',
            widget => 'selectBox',
            label => trm('Server'),
            cfg => {
                required => true,
                structure => $servers,
            },
        },
        {
            key => 'path',
            widget => 'text',
            label => trm('Path'),
            set => {
                width => 300,
                required => true,
                placeholder => trm('/absolte/path/to/archive/folder')
            },

        },
        {
            key => 'note',
            widget => 'textArea',
            label => trm('Note'),
            set => {
                width => 300,
                required => true,
                placeholder => trm('a note about the job for the person who is going to review your request.')
            },

        }
    ];
};

has actionCfg => sub ($self) {
    my $handler = sub ($self,$form) {
        $form->{path} =~ s{/*$}{/};
        return $self->app->dataSource->addArchiveJob({
            user => $self->user,
            server => $form->{server},
            path => $form->{path},
            note => $form->{note}})->then(sub ($data) {
            return {
                action => 'dataSaved',
                message => trm("Job added to the job list."),
                title => trm("Job Created"),
            }
        });
    };

    return [
        {
            label => trm('Add Job'),
            action => 'submit',
            key => 'save',
            actionHandler => $handler
        }
    ];
};

has checkAccess => sub ($self) {
    return $self->user->may('write');
};

1;


__END__

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2018-04-12 oetiker 0.0 first version

=cut
