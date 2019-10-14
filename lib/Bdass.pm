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
            quote_char => '"',
    ));
    $database->sql->migrations
        ->name('BdassBaseDB')
        ->from_data(__PACKAGE__,'appdb.sql')
        ->migrate;

    return $database;
};

has jsHid2Id => sub ($app) {
    my $js = {};
    $app->database->mojoSqlDb->select('js')->hashes->each(sub ($e, $num) {
        $js->{$e->{js_hid}} = $e->{js_id};
    });
    return $js;
};

has dataSource => sub ($app) {
    Bdass::Model::DataSource->new(app=>$app);
};

has userObject => sub {
    Bdass::Model::User->new;
};

sub _cleanJobDb ($app) {
    my $db = $app->database->mojoSqlDb;
    my $jsHid2Id = $app->jsHid2Id;
    my %map = (
        sizing => 'new',
        archiving => 'approved',
        verifying => 'archived'
    );
    for my $js (keys %map){
        $db->update('job',{
            job_js => $jsHid2Id->{$map{$js}}
        },{
            job_js => $jsHid2Id->{$js}
        });
    }
}

sub startup ($app) {
    my $cfg = $app->config->cfgHash;
    $app->_cleanJobDb;
    my %TLS;
    if (my $tls = $cfg->{BACKEND}{ad_tls}){
        %TLS = ( start_tls => $tls );
    }
    $app->plugin('SPNEGO',
        ad_server => $cfg->{BACKEND}{ad_uri},
        %TLS
    );
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
    VALUES ('approver','Approver');

CREATE TABLE IF NOT EXISTS js (
    js_id INTEGER PRIMARY KEY,
    js_hid TEXT UNIQUE
);

INSERT INTO js
    VALUES 
    (1,'new'),
    (2,'sizing'),
    (3,'sized'),
    (4,'approved'),
    (5,'archiving'),
    (6,'archived'),
    (7,'verifying'),
    (8,'verified'),
    (9,'error'),
    (10,'denied');
    
CREATE TABLE IF NOT EXISTS job (
    job_id INTEGER PRIMARY KEY AUTOINCREMENT,
    job_js INTEGER NOT NULL REFERENCES js(js_id) DEFAULT 1,
    job_token TEXT NOT NULL UNIQUE,
    job_cbuser INTEGER NOT NULL REFERENCES cbuser(cbuser_id),
    job_private BOOLEAN NOT NULL DEFAULT FALSE,
    job_group TEXT NOT NULL,
    job_server TEXT NOT NULL,
    job_size INTEGER,
    job_src TEXT NOT NULL,
    job_dst TEXT,
    job_name TEXT NOT NULL,
    job_project TEXT NOT NULL,
    job_note TEXT NOT NULL,
    job_decision TEXT,
    job_ts_created TIMESTAMP NOT NULL DEFAULT (strftime('%s', 'now')),
    job_ts_updated TIMESTAMP NOT NULL DEFAULT (strftime('%s', 'now'))
);

CREATE TABLE IF NOT EXISTS history (
    history_id INTEGER PRIMARY KEY AUTOINCREMENT,
    history_job INTEGER NOT NULL REFERENCES job(job_id) ON DELETE CASCADE,
    history_cbuser INTEGER REFERENCES cbuser(cbuser_id),
    history_ts TIMESTAMP NOT NULL DEFAULT (strftime('%s', 'now')),
    history_js INTEGER NOT NULL REFERENCES js(js_id),
    history_note TEXT
);

ALTER TABLE cbuser ADD cbuser_groups TEXT default '{}';
ALTER TABLE cbuser ADD cbuser_email TEXT NOT NULL default "-@-";

CREATE VIRTUAL TABLE IF NOT EXISTS file USING fts4(
    file_job,
    file_owner,
    file_size,
    file_date,
    file_name,
    notindexed=file_size,
    notindexed=file_job
);

CREATE TABLE IF NOT EXISTS task (
    task_id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_cbuser INTEGER REFERENCES cbuser(cbuser_id),
    task_call TEXT NOT NULL,
    task_arguments TEXT, -- JSON
    task_status TEXT,
    task_ts_created TIMESTAMP NOT NULL DEFAULT (strftime('%s', 'now')),
    task_ts_started TIMESTAMP,
    task_ts_done TIMESTAMP
);

