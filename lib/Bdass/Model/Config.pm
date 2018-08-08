package Bdass::Model::Config;
use Mojo::Base qw(CallBackery::Config);
use File::Spec;

=head1 NAME

Bdass::Model::Config - custom enhancements for configuring Bdass

=head1 SYNOPSIS

 use Bdass::Model::Config;
 my $cfg = Bdass::Model::Config ->new(file=>$file);
 my $hash_ref = $cfg->cfgHash();
 my $pod = $cfg->pod();

=head1 DESCRIPTION

See L<CallBackery::Config>

=cut

has 'app';

has pluginPath => sub { ['Bdass::ConnectionPlugin']; };

has pluginList {
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
}

has grammar => sub {
    my $self = shift;
    my $gr = $self->SUPER::grammar;
    my $app = $self->app;
    $gr->{CONNECTIONS} = {
        _vars => [],
        _sections => ['/\S+/'],
        _mandatory => [],
        '/\S+/' => {
            _vars => [qw(name plugin)],
            _sections => [qw(pluginCfg)],
            _mandatory => [qw(name plugin)],
            name => {
                _doc => 'Display name for this instance'
            },
            plugin => {
                _doc => 'Source plugin to use for this instance',
                _dyn => sub {
                    my $var   = shift;
                    my $plugin = shift;
                    my $tree = shift;
                    $plugin = $self->instantiatePlugin($plugin) if not ref $plugin;
                    $tree->{pluginCfg} = $plugin->grammar();
                },
                _dyndoc => $self->pluginList
                    
                }
            },
            pluginCfg => {
                _doc => 'Plugin specific configuration'
                
            }
        },
    };
    return $gr;
};

sub instantiatePlugin {
    my $self   = shift;
    my $plugin = shift;

    my $pluginPath = $self->pluginPath;
    for my $path (@INC){
        for my $pPath (@$pluginPath) {
            my @pDirs = split /::/, $pPath;
            my $fPath = File::Spec->catdir($path, @pDirs, '*.pm');
            for my $file (glob($fPath)) {
                my ($volume, $modulePath, $moduleName) = File::Spec->splitpath($file);
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

1;
