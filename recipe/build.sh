#!/bin/bash

if [ -z "$LD_LIBRARY_PATH" ]; then
    old_ld_library_path="$LD_LIBRARY_PATH"
fi

export LD_LIBRARY_PATH=$(pwd)

# world-writable files are not allowed
chmod -R o-w $SRC_DIR

sh Configure -de -Dprefix=$PREFIX -Duserelocatableinc
make

# change permissions again after building
chmod -R o-w $SRC_DIR

make test
make install

if [ ! -z "$old_ld_library_path" ]; then
    export LD_LIBRARY_PATH="$old_ld_library_path"
fi
