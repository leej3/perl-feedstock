#!/bin/bash

export LD_LIBRARY_PATH=$(pwd)

# world-writable files are not allowed
chmod -R o-w $SRC_DIR

sh Configure -Dusethreads -Duserelocatableinc -Dprefix=$PREFIX -de
make

# change permissions again after building
chmod -R o-w $SRC_DIR

make test
make install
