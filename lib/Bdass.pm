package Bdass;

use Mojo::Base 'CallBackery';

=head1 NAME

Bdass - the application class

=head1 SYNOPSIS

 use Mojolicious::Commands;
 Mojolicious::Commands->start_app('Bdass');

=head1 DESCRIPTION

Configure the mojolicious engine to run our application logic

=cut

=head1 ATTRIBUTES

Bdass has all the attributes of L<CallBackery> plus:

=cut

=head2 config

use our own plugin directory and our own configuration file:

=cut

has config => sub {
    my $self = shift;
    my $config = $self->SUPER::config(@_);
    $config->file($ENV{Bdass_CONFIG} || $self->home->rel_file('etc/bdass.cfg'));
    unshift @{$config->pluginPath}, 'Bdass::GuiPlugin';
    return $config;
};

has database => sub {
    my $self = shift;
    my $database = $self->SUPER::database(@_);
    $database->sql->migrations
        ->name('BdassBaseDB')
        ->from_data(__PACKAGE__,'appdb.sql')
        ->migrate;
    return $database;
};

sub startup {
    my $app = shift;
    $app->config->cfgHash; # read and validate config
    unshift @{$app->commands->namespaces},  __PACKAGE__.'::Command';
    $app->SUPER::startup(@_);
};
1;

=head1 COPYRIGHT

Copyright (c) 2018 by Tobias Oetiker. All rights reserved.

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=cut

__DATA__

@@ appdb.sql

-- 1 up

CREATE TABLE song (
    song_id    INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    song_title TEXT NOT NULL,
    song_voices TEXT,
    song_composer TEXT,
    song_page INTEGER,
    song_note TEXT
);

-- add an extra right for people who can edit

INSERT INTO cbright (cbright_key,cbright_label)
    VALUES ('write','Editor');

-- 1 down

DROP TABLE song;
