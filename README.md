# Big Data Archive System Service

#VERSION#, #DATE#

Handle archiving of large data Folders to archival storage systems. With large multi terrabyte datasets such
data archiving and migration can be both time consuming as well as costly. In a heterogeneous

## Installation

Unpack the tar archivt back to your app source directory and start building.
If you come from installing callbackery make sure to do the following
in a new terminal or unset $PERL5LIB

```console
./configure --prefix=$HOME/opt/bdass
make
```

Configure will check if all requirements are met and give
hints on how to fix the situation if something is missing.

Any mising perl modules will be built when you type `make`.

To install the application, just run

   make install

You can now run bdass.pl in reverse proxy mode.

   cd $HOME/opt/bdass/bin
   ./bdass.pl prefork

## Development

While developing the application it is convenient to NOT have to install it
before runnning. You can actually serve the Qooxdoo source directly
using the built-in Mojo webserver.

To get this going you first have to provide a copy of the qooxdoo-sdk
and run configure accordingly

```console
git clone --depth=1 https://github.com/qooxdoo/qooxdoo.git qooxdoo-sdk
./configure --with-qooxdoo-sdk-dir=$(pwd)/qooxdoo-sdk
make
```

then you can run the dev version

```console
cd bin
./bdass-source-mode.sh
```

If you need any additional perl modules, write their names into the PERL_MODULES
file and run make again

## Packaging

Before releasing, make sure to update CHANGES, VERSION and run ./bootstrap

You can also package the application as a nice tar.gz file, it will contain
a mini copy of cpan, so that all perl modules can be rebuilt at the
destination.  If you want to make sure that your project builds with perl
5.10.1 but you are not working with perl 5.10.1 (hopefully) you can use
perlbrew to install the old version and then do:

```console
make clean
touch PERL_MODULES
make PERL=perl5.10.1
make clean
make dist
```

now your package contains all the modules required to build on a system with perl-5.10.1. Not that I would recommend doing that!

Enjoy!

Tobias Oetiker <tobi@oetiker.ch>
