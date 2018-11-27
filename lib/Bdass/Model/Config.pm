package Bdass::Model::Config;
use Mojo::Base 'CallBackery::Config', -signatures;
use File::Spec;
use Mojo::Util qw(dumper);
use Mojo::URL;

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
                my ($volume, $modulePath, $moduleName) = File::Spec->splitpath($file);
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
    $gr->{CONNECTION} = {
        _vars => [],
        _sections => ['/\S+/'],
        _mandatory => [],
        '/\S+/' => {
            _vars => [qw(name plugin url)],
            _sections => [qw(Folders)],
            _mandatory => [qw(name plugin url Folders)],
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
            },
            Folders => {
                _doc => 'list of directories to scan',
                _table => {
                    0 => {
                        _doc => 'directory'
                    }
                }
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
    for my $key (keys %{$cfg->{CONNECTION}}){
        my $pcfg = $cfg->{CONNECTION}{$key};
        my $plugin = $pcfg->{plugin};
        $plugin->name($pcfg->{name});
        $plugin->connectionId($key);
        $plugin->url(Mojo::URL->new($pcfg->{url}));
        $pcfg->{Folders} = [
            map {$_->[0]} @{$pcfg->{Folders}{_table}}];
        $plugin->folderList($pcfg->{Folders});
        $plugin->app($self->app);
    }
    return $cfg;
}
1;
