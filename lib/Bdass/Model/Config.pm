package Bdass::Model::Config;
use Mojo::Base 'CallBackery::Config', -signatures;
use File::Spec;
use Mojo::Util qw(dumper);
use Mojo::URL;
use Mojo::Promise;

=head1 NAME

Bdass::Model::Config - custom enhancements for configuring Bdass

=head1 SYNOPSIS

 use Bdass::Model::Config;
 my $cfg = Bdass::Model::Config->new(file=>$file);
 my $hash_ref = $cfg->cfgHash();
 my $pod = $cfg->pod();

=head1 DESCRIPTION

See L<CallBackery::Config>

=cut

has 'app';

has connectionPluginPath => sub { ['Bdass::ConnectionPlugin']; };

has connectionPluginList => sub {
    my $self = shift;
    my $paths = shift;
    my $pluginList = {};
    for my $path (@INC){
        for my $pPath (@$paths) {
            my @pDirs = split /::/, $pPath;
            my $fPath = File::Spec->catdir($path, @pDirs, '*.pm');
            for my $file (glob($fPath)) {
                my ($volume, $modulePath, $moduleName) 
                    = File::Spec->splitpath($file);
                $moduleName =~ s{\.pm$}{};
                $pluginList->{$moduleName} = 'Connection Plugin Module';
            }
        }
    }
    return $pluginList;
};

has grammar => sub {
    my $self = shift;
    my $gr = $self->SUPER::grammar;
    push @{$gr->{_sections}},'CONNECTION';
    push @{$gr->{_mandatory}},'CONNECTION';
    push @{$gr->{BACKEND}{_vars}},'ad_uri','admin_group','smtp_server','mail_from','admin_email';
    push @{$gr->{BACKEND}{_mandatory}},'ad_uri','admin_group','smtp_server','mail_from','admin_email';
    $gr->{BACKEND}{ad_uri} = { _doc => 'AD URI - ldap://ad1.company.com'};
    $gr->{BACKEND}{admin_group} = { _doc => 'admin group from AD'};
    $gr->{BACKEND}{mail_from} = { _doc => 'mail from'}; 
    $gr->{BACKEND}{admin_email} = { _doc => 'admin email address'};
    $gr->{BACKEND}{smtp_server} = { _doc => 'smtp server host'};
    push @{$gr->{BACKEND}{_sections}},'ad_tls';
    push @{$gr->{BACKEND}{ad_tls}{_vars}}, 
        qw(verify sslversion sslserver ciphers clientcert clientkey keydecrypt capath cafile checkcrl);
    $gr->{CONNECTION} = {
        _vars => [],
        _sections => ['/\S+/'],
        _mandatory => [],
        '/\S+/' => {
            _vars => [qw(name plugin url)],
            _mandatory => [qw(name plugin url)],
            name => {
                _doc => 'Display name for this instance'
            },
            plugin => {
                _doc => 'Source plugin to use for this instance',
                _sub => sub {
                    eval {
                        $_[0] = $self->instantiateConnectionPlugin($_[0]);
                    };
                    if ($@){
                        return "Failed to load Plugin $_[0]: $@";
                    }
                    return undef;
                },
            },
            url => {
                _doc => 'url to connect to'
            }
        },
    };
    return $gr;
};

sub instantiateConnectionPlugin ($self,$plugin) {

    my $pluginPath = $self->connectionPluginPath;
    for my $path (@INC){
        for my $pPath (@$pluginPath) {
            my @pDirs = split /::/, $pPath;
            my $fPath = File::Spec->catdir($path, @pDirs, '*.pm');
            for my $file (glob($fPath)) {
                my ($volume, $modulePath, $moduleName) 
                    = File::Spec->splitpath($file);
                $moduleName =~ s{\.pm$}{};
                if ($plugin eq $moduleName) {
                    require $file;
                    no strict 'refs';
                    return "${pPath}::${plugin}"->new();
                }
            }
        }
    }
    die "Plugin Module $plugin not found";
};

sub postProcessCfg ($self,$cfg) {
    $self->SUPER::postProcessCfg($cfg);
    my @hostChecks;
    for my $key (keys %{$cfg->{CONNECTION}}){
        my $pcfg = $cfg->{CONNECTION}{$key};
        my $plugin = $pcfg->{plugin};
        $plugin->name($pcfg->{name});
        $plugin->connectionId($key);
        $plugin->url(Mojo::URL->new($pcfg->{url}));
        $plugin->app($self->app);
        my $status = $plugin->checkHost;
        if (not $status){
            die "connection $key is not working\n";
        }
    }
    return $cfg;
}
1;
