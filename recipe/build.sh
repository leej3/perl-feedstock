#!/bin/bash

if [[ "$build_platform" == "osx-64" && "$target_platform" == "osx-arm64" ]]; then
  ARCHFLAGS="-arch x86_64 -arch arm64"
  export MACOSX_DEPLOYMENT_TARGET=10.9
fi

if [[ "$target_platform" == osx-* ]]; then
  if [[ "$target_platform" == osx-64 ]]; then
    CFLAGS="${CFLAGS} -D_DARWIN_FEATURE_CLOCK_GETTIME=0"
  fi
  CCFLAGS="${CFLAGS} -fno-common -DPERL_DARWIN -no-cpp-precomp -Werror=partial-availability -D_DARWIN_FEATURE_CLOCK_GETTIME=0 -fno-strict-aliasing -pipe -fstack-protector-strong -DPERL_USE_SAFE_PUTENV ${ARCHFLAGS} ${CPPFLAGS}"
elif [[ "$target_platform" == linux-* ]]; then
  CCFLAGS="${CFLAGS} -D_REENTRANT -D_GNU_SOURCE -fwrapv -fno-strict-aliasing -pipe -fstack-protector-strong -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -D_FORTIFY_SOURCE=2"
fi

# world-writable files are not allowed
chmod -R o-w "${SRC_DIR}"

declare -a _config_args
_config_args+=(-Dprefix="${PREFIX}")
_config_args+=(-Dusethreads)
_config_args+=(-Duserelocatableinc)
_config_args+=(-Dcccdlflags="-fPIC")
_config_args+=(-Dldflags="${LDFLAGS} ${ARCHFLAGS}")
# .. ran into too many problems with '.' not being on @INC:
_config_args+=(-Ddefault_inc_excludes_dot=n)

if [[ -n "${CCFLAGS}" ]]; then
  _config_args+=(-Dccflags="${CCFLAGS}")
fi
if [[ -n "${GCC:-${CC}}" ]]; then
  _config_args+=("-Dcc=${GCC:-${CC}}")
fi
if [[ -n "${AR}" ]]; then
  _config_args+=("-Dar=${AR}")
fi
if [[ ${HOST} =~ .*linux.* ]]; then
  _config_args+=(-Dlddlflags="-shared ${LDFLAGS}")
# elif [[ ${HOST} =~ .*darwin.* ]]; then
#   _config_args+=(-Dlddlflags=" -bundle -undefined dynamic_lookup ${LDFLAGS}")
fi
# -Dsysroot prevents Configure rummaging around in /usr and
# linking to system libraries (like GDBM, which is GPL). An
# alternative is to pass -Dusecrosscompile but that prevents
# all Configure/run checks which we also do not want.
_config_args+=("-Dsysroot=${CONDA_BUILD_SYSROOT}")

./Configure -de "${_config_args[@]}"
make

# change permissions again after building
chmod -R o-w "${SRC_DIR}"

# Seems we hit:
# lib/perlbug .................................................... # Failed test 21 - [perl \#128020] long body lines are wrapped: maxlen 1157 at ../lib/perlbug.t line 154
# FAILED at test 21
# https://rt.perl.org/Public/Bug/Display.html?id=128020
# make test
make install

# Replace hard-coded BUILD_PREFIX by value from env as CC, CFLAGS etc need to be properly set to be usable by ExtUtils::MakeMaker module
(cd $PREFIX/lib/5*/*-thread-*/ && patch -p1) < $RECIPE_DIR/dynamic_config.patch
sed -i.bak "s|\\(='[^'\\@]*\\)@|\\1\\\\@|g" $PREFIX/lib/*/*/Config_heavy.pl
sed -i.bak "s|${BUILD_PREFIX}|\$compilerroot|g" $PREFIX/lib/*/*/Config_heavy.pl

sed -i.bak "s|cc => '\(.*\)'|cc => \"\1\"|g" $PREFIX/lib/*/*/Config.pm
sed -i.bak "s|libpth => '\(.*\)'|libpth => \"\1\"|g" $PREFIX/lib/*/*/Config.pm
sed -i.bak "s|${BUILD_PREFIX}|\$compilerroot|g" $PREFIX/lib/*/*/Config.pm

# 2 more seds for osx:
sed -i.bak "s|\\\c|\\\\\\\c|g" $PREFIX/lib/*/*/Config_heavy.pl
sed -i.bak "s|DPERL_SBRK_VIA_MALLOC \$ccflags|DPERL_SBRK_VIA_MALLOC \\\\\$ccflags|g" $PREFIX/lib/*/*/Config_heavy.pl

rm $PREFIX/lib/*/*/Config_heavy.pl.bak $PREFIX/lib/*/*/Config.pm.bak

grep -Iir "\-arch x86_64" $PREFIX
