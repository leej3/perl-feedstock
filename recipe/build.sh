#!/bin/bash
sh Configure -Dusethreads -Duserelocatableinc -Dprefix=$PREFIX -de
make
make test
make install
