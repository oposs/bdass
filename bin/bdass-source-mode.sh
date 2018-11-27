#!/bin/sh
export QX_SRC_MODE=1
# relative to the application home
export QX_SRC_PATH=frontend/source
export MOJO_MODE=development
export MOJO_LOG_LEVEL=debug
exec ./bdass.pl prefork --listen 'http://*:5565'
