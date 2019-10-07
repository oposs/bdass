package Bdass::GuiPlugin::JobForm;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractForm', -signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use POSIX qw(strftime);
use Mojo::JSON qw(true false);
use Bdass::ConnectionPlugin::base;
use String::Random;

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

my $tokenPattern = '[a-zA-Z][_a-zA-Z0-9]{18}[A-Za-z0-9]';
my $tokenPrefix = Bdass::ConnectionPlugin::base->new->tokenFilePrefix;
my $tokenPostfix = '.txt';


has formCfg => sub {
    my $self = shift;
    my $db = $self->user->db;
    my $con = $self->app->config->cfgHash->{CONNECTION};
    my $servers = [ map {
        { key => $_,
          title => $con->{$_}{plugin}->name,
        }
    } keys %$con ];
    my $grHash = $self->user->userInfo->{groups};
    my $groups = [ map {
        {
            key => $_,
            title => $_
        }
    } keys %$grHash ];
    return [
        {
            widget => 'header',
            label => trm('Meta Information'),
        },
        {
            key => 'name',
            widget => 'text',
            label => trm('Archive Name'),
            set => {
                width => 300,
                required => true,
                placeholder => trm('a descriptive name')
            },

        },
        {
            key => 'project',
            widget => 'text',
            label => trm('Project Name'),
            set => {
                width => 300,
                required => true,
                placeholder => trm('which project does this archive belong to?')
            },

        },
        {
            widget => 'header',
            label => trm('Archive Job Creation'),
            note => trm('In order to register a folder for archiving, you have to prove that you have write access to it. You do this by creating archive token file in the folder you want to get archived. Every job gets a unique archive token filename.'),
        },

        {
            key => 'token',
            widget => 'text',
            label => trm('Token File'),
            set => {
                readOnly => true,
                nativeContextMenu => true,
            },
            getter => sub ($self) {
                return $tokenPrefix
                    . String::Random->new->randregex($tokenPattern)
                    . $tokenPostfix,
            },
            validator => sub ($value,$field,$form) {
                if ($value
                    !~ m{^\Q${tokenPrefix}\E${tokenPattern}\Q${tokenPostfix}\E$}){
                    return "Invalid Token";
                }
                return undef;
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
            validator => sub {
                my $key = shift;
                return "invalid server" unless exists $con->{$key};
                return "";
            }
        },
        
        {
            key => 'path',
            widget => 'text',
            label => trm('Path'),
            set => {
                width => 300,
                required => true,
                placeholder => trm('/absolute/path/to/archive/folder')
            },

        },
        {
            widget => 'header',
            label => trm('Archive Ownership')
        },
        {
            key => 'group',
            widget => 'selectBox',
            label => trm('Group'),
            cfg => {
                required => true,
                structure => $groups
            },
            validator => sub {
                my $group = shift;
                return "invalid group" if not exists $grHash->{$group};
                return "";
            }

        },
        {
            key => 'private',
            widget => 'checkBox',
            label => trm('Private Archive'),
            cfg => {
                required => true,
            },
        },
        {
            widget => 'header',
            label => trm('Extra Info')
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
        if ( $form->{token}
            =~ /^\Q${tokenPrefix}\E(${tokenPattern})\Q${tokenPostfix}\E$/ ) {
            return $self->app->dataSource->addArchiveJob({
                user => $self->user,
                token => $1,
                group => $form->{group},
                private => $form->{private},
                server => $form->{server},
                path => $form->{path},
                note => $form->{note},
                name => $form->{name},
                project => $form->{project},
            })->then(sub ($data) {
                return {
                    action => 'dataSaved',
                    message => trm("Job added to the job list."),
                    title => trm("Job Created"),
                }
            });
        };
        die mkerror(4384,"Invalid Token String");
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


1;


__END__

=head1 COPYRIGHT

Copyright (c) 2018 by OETIKER+PARTNER AG. All rights reserved.

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2018-04-12 oetiker 0.0 first version

=cut
