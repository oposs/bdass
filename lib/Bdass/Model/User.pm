package Bdass::Model::User;

=head1 NAME

Bdass::Model::User - Bdass specific user

=cut

use Mojo::Base 'CallBackery::User';
use CallBackery::Exception qw(mkerror);
use Mojo::Util qw(b64_encode sha1_sum);


1;
