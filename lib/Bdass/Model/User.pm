package Bdass::Model::User;

=head1 NAME

Bdass::Model::User - Bdass specific user

=cut

use Mojo::Base 'CallBackery::User';
use CallBackery::Exception qw(mkerror);
use Mojo::Util qw(b64_encode sha1_sum dumper);
use Mojo::JSON qw(encode_json decode_json);

has userId => sub {
    shift->userInfo->{cbuser_id};
};

sub provisionOrUpdateUser {
    my $self = shift;
    my $user = shift;
    my $groups = shift;
    my $userInfo = $self->db->fetchRow('cbuser',{login=>$user->{samaccountname}});

    my $data = {
        login => $user->{samaccountname},
        given => $user->{givenname},
        family => $user->{sn},
        groups => encode_json($groups),
    };

    if (not $userInfo){
        $data->{note} = 'auto provisioned '.localtime(time);
    }
    else {
        $data->{id} = $userInfo->{cbuser_id};
    }

    $self->db->updateOrInsertData('cbuser',{
           map { $_ => $data->{$_} } qw(login family given groups note)
    },$data->{id} ? { id => int($data->{id}) } : ());
}

has userInfo => sub {
    my $self = shift;
    my $userId = $self->cookieConf->{u};
    if (not $userId) {
        $self->controller->ntlm_auth({
            auth_success_cb => sub {
                my $c = shift;
                my $user = shift;
                my $ldap = shift; # bound Net::LDAP::SPNEGO connection
                my $groups = $ldap->get_ad_groups($user->{samaccountname});
                $self->log->debug(dumper $groups);
                $userId = $self->provisionOrUpdateUser($user,$groups);
                return 1; # 1 is you are happy with the outcome
            }
        }) or return undef;
    }
    # prevent recursion by already setting the userId
    $self->userId($userId);

    my $info = $self->db->fetchRow('cbuser',{id=>$self->userId});
    $info->{sessionCookie} = $self->makeSessionCookie();
    delete $info->{cbuser_groups};
    return $info;
};

has loginName => sub {
    shift->userInfo->{email} // '*UNKNOWN*';
};

# this decides if the user can login
has isUserAuthenticated => sub {
    my $self = shift;

    $self->userId ? 1 : 0;
};


1;
