package Bdass::Model::DataSource;

use Mojo::Base -base,-signatures;
use Time::HiRes qw(gettimeofday);
=head1 NAME

Bdass::Model::ArchiveCandidate - ArchiveCandidate Model

=head1 SYNOPSIS

 use Bdass::Model::DataSource;
 my $src = Bdass::Model::DataSource->new;

=head1 DESCRIPTION

=cut

has 'app';
has log => sub { shift->app->log };
has cfg => sub {
    shift->app->config->cfgHash;
};

=head2 getArchiveCandidates($token)

Return returns a Promise resolving to the list of jobs pending for the user.

=cut

my $cache;
my $cacheUpdated;
my $updateDuration;

sub getArchiveCandidates ($self,$token=undef) {
    my @work;
    my @data;
    my $updateStart = gettimeofday;
    if ($cache and $cacheUpdated + 10 * $updateDuration + 10 > $updateStart) {
        my $pr = Mojo::Promise->new;
        Mojo::IOLoop->next_tick(sub{
            my $age = gettimeofday - $cacheUpdated;
            $self->log->debug("archive candidates from cache (${age}s old");
            $pr->resolve([ grep { not $token or $_->{token} eq $token }  @$cache ]);
        });
        return $pr;
    }

    for my $key (keys %{$self->cfg->{CONNECTION}}){
        my $plugin = $self->cfg->{CONNECTION}{$key}{plugin};
        push @work,$plugin->listFolders->then(sub {
            my $result = shift;
            push @data,@$result;
            $self->app->log->debug($key." done");
            return 1;
        });
    }
    return Mojo::Promise->all(@work)->then(sub {
        $cacheUpdated = gettimeofday;
        $updateDuration = $cacheUpdated - $updateStart;
        $self->log->debug("archive candidates updated in ${updateDuration}s");
        $cache = \@data;
        return [ grep { not $token or $_->{token} eq $token } @data ];
    });
}

1;