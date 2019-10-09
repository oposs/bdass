package Bdass::Model::Mail;

use Mojo::Base -base,-signatures;
use Email::MIME;
use Email::Sender::Simple;
use Email::Sender::Transport::SMTP;
use Email::Sender::Transport::Test;


has 'app';

has log => sub ($self) {
    $self->app->log
};

has cfg => sub ($self) {
    $self->app->config->cfgHash;
};

has mailTransport => sub {
    my $self = shift;
    if ($ENV{HARNESS_ACTIVE}) {
        return Email::Sender::Transport::Test->new();
    }
    return Email::Sender::Transport::SMTP->new({
        host => $self->cfg->{BACKEND}{smtp_server},
    });
};

has mailFrom => sub {
    $self->cfg->{BACKEND}{mail_from};
}

has sql => sub ($self) {
    $self->app->database->sql
};

=head3 sendMail($to,$subject,$message)

send email

=cut

sub sendMail ($self,$to,$subject,$message) {
    if ($to =~ /^job:(\d+)/){
        $self->sql->db->select(['cbuser' =>
            [ job => 'job_cbuser', 'cbuser_id']
        ],'cbuser_mail',{
            job_id => $1;
        });
    }
    eval {
        my $email = Email::MIME->create(
            header_str => [
                To      => $to,
                From    => $self->mailFrom,
                Subject => $subject,
            ],
            body_str => $message,
            attributes  => {
                charset => 'UTF-8',
                encoding => 'quoted-printable',
                content_type => "text/plain",
            }
        );
        Email::Sender::Simple->send($email, {
            transport => $self->mailTransport
        });
    };
    if ( $@ ) {
        $self->log->error("Sending mail to $to: $@");
    }
}