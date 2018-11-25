package Bdass;

use Mojo::Base 'CallBackery';
use Bdass::Model::Config;
use Bdass::Model::User;

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
    my $config = Bdass::Model::Config->new(app=>$self);
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

has userObject => sub {
    Bdass::Model::User->new;
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

INSERT INTO cbright (cbright_key,cbright_label)
    VALUES ('write','Writer');

CREATE TABLE IF NOT EXISTS js (
    js_id INTEGER PRIMARY KEY,
    js_name TEXT
);

INSERT INTO js
    VALUES (1,'new'),(2,'approved'),
    (3,'processing'),(4,'archived'),
    (5,'cancled'),(6,'denied');
    
CREATE TABLE IF NOT EXISTS job (
    job_id  INTEGER PRIMARY KEY AUTOINCREMENT,
    job_cbuser INTEGER NOT NULL REFERENCES cbuser(cbuser_id),
    job_src TEXT NOT NULL,
    job_dst TEXT,
    job_ts_created TIMESTAMP NOT NULL DEFAULT (strftime('%s', 'now'))
);
