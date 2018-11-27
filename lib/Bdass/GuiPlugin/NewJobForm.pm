package Bdass::GuiPlugin::NewJobForm;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractForm';
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use POSIX qw(strftime);

=head1 NAME

Bdass::GuiPlugin::NewJobForm - Job Edit Form

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

    return [
        $self->config->{type} eq 'edit' ? {
            key => 'job_id',
            label => trm('JobId'),
            widget => 'hiddenText',
            set => {
                readOnly => $self->true,
            },
        } : (),

        {
            key => 'job_title',
            label => trm('Title'),
            widget => 'text',
            set => {
                required => $self->true,
            },
        },
        {
            key => 'job_src_host',
            label => trm('Source Host'),
            widget => 'selectBox',
            
        },
        {
            key => 'job_note',
            label => trm('Note'),
            widget => 'textArea',
            note => trm('Use this area to write down additional notes on the particular job.'),
            set => {
                placeholder => 'some extra information about this job',
            }
        },
    ];
};

has actionCfg => sub {
    my $self = shift;
    my $type = $self->config->{type} // 'new';

    my $handler = sub {
        my $args = shift;

        my @fields = qw(title note);

        my $db = $self->user->db;

        my $id = $db->updateOrInsertData('job',{
            map { $_ => $args->{'job_'.$_} } @fields
        },$args->{job_id} ? { id => int($args->{job_id}) } : ());
        return {
            action => 'dataSaved'
        };
    };

    return [
        {
            label => $type eq 'edit'
               ? trm('Save Changes')
               : trm('Add Job'),
            action => 'submit',
            key => 'save',
            handler => $handler
        }
    ];
};

has grammar => sub {
    my $self = shift;
    $self->mergeGrammar(
        $self->SUPER::grammar,
        {
            _doc => "Job Configuration",
            _vars => [ qw(type) ],
            type => {
                _doc => 'type of form to show: edit, add',
                _re => '(edit|add)'
            },
        },
    );
};

sub getAllFieldValues {
    my $self = shift;
    my $args = shift;
    return {} if $self->config->{type} ne 'edit';
    my $id = $args->{selection}{job_id};
    return {} unless $id;

    my $db = $self->user->db;
    my $data = $db->fetchRow('job',{id => $id});
    return $data;
}

has checkAccess => sub {
    my $self = shift;
    return $self->user->may('write');
};

1;
__END__

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2018-04-12 oetiker 0.0 first version

=cut
