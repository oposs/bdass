package Bdass;

use Mojo::Base 'CallBackery', -signatures;
use Bdass::Model::Config;
use Bdass::Model::User;
use Bdass::Model::DataSource;
use SQL::Abstract::Pg;
use Bdass::Command::jobrunner;
use Mojo::IOLoop::Subprocess;

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

has config => sub ($self) {
    my $config = Bdass::Model::Config->new(app=>$self);
    $config->file($ENV{Bdass_CONFIG} || $self->home->rel_file('etc/bdass.cfg'));
    unshift @{$config->pluginPath}, 'Bdass::GuiPlugin';
    return $config;
};

has database => sub ($self,@args) {
    my $database = $self->SUPER::database(@args);
    $database->sql->abstract(
        SQL::Abstract::Pg->new(
            name_sep => '.', 
            quote_char => '"'
    ));
    $database->sql->migrations
        ->name('BdassBaseDB')
        ->from_data(__PACKAGE__,'appdb.sql')
        ->migrate;
    return $database;
};

has dataSource => sub ($app) {
    Bdass::Model::DataSource->new(app=>$app);
};

has userObject => sub {
    Bdass::Model::User->new;
};

sub startup ($app) {
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

INSERT INTO cbright (cbright_key,cbright_label)
    VALUES ('write','Writer');

CREATE TABLE IF NOT EXISTS js (
    js_id INTEGER PRIMARY KEY,
    js_name TEXT
);

INSERT INTO js
    VALUES 
    (1,'new'),
    (2,'sizing'),
    (3,'sized'),
    (4,'authorized'),
    (5,'archiving'),
    (6,'complete'),
    (7,'error');
    
CREATE TABLE IF NOT EXISTS job (
    job_id  INTEGER PRIMARY KEY AUTOINCREMENT,
    job_js INTEGER REFERENCES js(js_id) DEFAULT 1,
    job_cbuser INTEGER NOT NULL REFERENCES cbuser(cbuser_id),
    job_server TEXT NOT NULL,
    job_size INTEGER,
    job_src TEXT NOT NULL,
    job_token_ts TIMESTAMP NOT NULL,
    job_dst TEXT,
    job_note TEXT,

    job_ts_created TIMESTAMP NOT NULL DEFAULT (strftime('%s', 'now'))
);
