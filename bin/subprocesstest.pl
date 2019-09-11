#!/usr/bin/env perl
use Carp;
$SIG{ __DIE__ } = sub { Carp::confess( @_ ) };

use lib qw(); # PERL5LIB
use FindBin;use lib "$FindBin::RealBin/../lib";use lib "$FindBin::RealBin/../thirdparty/lib/perl5"; # LIBDIR
use Data::Dumper;
use Mojo::Base -signatures;
use Mojo::IOLoop::Stream;
use IPC::Open3;

my $wtr = IO::Handle->new;
my $rdr = IO::Handle->new;
my $err = IO::Handle->new;

my $pid = open3($wtr, $rdr, $err, 
    'dd','if=/dev/zero','bs=10M','count=1000');

sub hook ($fh,$name) {
    my $st = Mojo::IOLoop::Stream->new($fh);
    $st->timeout(0);
    $st->on(close => sub ($st) {
        $st->stop;
        print "$name closed\n";
    });
    $st->on(error => sub ($st,$err) {
        $st->stop;
        print "$name error $err\n";
    });
    return $st;
}

my $rdStr = hook($rdr,'STDOUT');
my $errStr = hook($err,'STDERR');
my $wrStr = hook($wtr,'STDIN');

$rdStr->on(read => sub ($stream,$bytes) {
   print "STDOUT - ".length($bytes)."\n";
   # $wrStr->write("Gugüs\n");
});
$rdStr->start;
$errStr->on(read => sub ($stream,$bytes) {
    print "STDERR - $bytes\n";
});
$errStr->start;
$wrStr->start;

$wrStr->write("HELLO\n");
$wrStr->stop;
Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
