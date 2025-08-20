FROM buildpack-deps:oldstable-curl
LABEL org.opencontainers.image.authors="Authelia Team <team@authelia.com>"
LABEL org.authelia.image.prune.protection="true"

ENV \
  CGO_CPPFLAGS="-D_FORTIFY_SOURCE=2 -fstack-protector-strong" \
  CGO_LDFLAGS="-Wl,-z,relro,-z,now" \
  CROSS_TRIPLE="x86_64-linux-gnu" \
  GOROOT="/usr/local/go" \
  LD_LIBRARY_PATH="/usr/x86_64-pc-freebsd14/lib:$LD_LIBRARY_PATH" \
  PATH="/root/go/bin:/usr/local/go/bin:$PATH"

RUN <<EOF
  echo "Starting image build for Debian oldstable"
  echo 'deb [trusted=yes] https://repo.goreleaser.com/apt/ /' > /etc/apt/sources.list.d/goreleaser.list
  dpkg --add-architecture arm64
  dpkg --add-architecture armhf
  apt-get update
  apt-get install -y -q \
    autoconf \
    automake \
    autotools-dev \
    binutils-multiarch \
    binutils-multiarch-dev \
    build-essential \
    ccache \
    crossbuild-essential-arm64 \
    crossbuild-essential-armhf \
    curl \
    git-core \
    goreleaser \
    libssl-dev \
    libxml2-dev \
    lzma-dev \
    multistrap \
    openssl \
    wget \
    xz-utils
  apt-get -y clean
EOF

ARG GCC_VERSION="15.1.0"
ARG LINUX_VERSION="5.8.5"
ARG MUSL_TRIPLES="x86_64-linux-musl,aarch64-linux-musl,arm-linux-musleabihf"

RUN <<EOF
  cd /tmp
  git clone https://github.com/richfelker/musl-cross-make
  cd musl-cross-make
  for triple in $(echo ${MUSL_TRIPLES} | tr "," " "); do
    make TARGET=${triple} OUTPUT=/usr GCC_VER=${GCC_VERSION} LINUX_VER=${LINUX_VERSION} install
  done
  cd /tmp && rm -rf /tmp/*
EOF

ARG GNU_MIRROR="https://mirrors.middlendian.com/gnu"
ARG FREEBSD_VERSION="14.3"
ARG FREEBSD_PREFIX="x86_64-pc-freebsd14"
ARG BINUTILS_VERSION="2.44"
ARG GMP_VERSION="6.3.0"
ARG MPFR_VERSION="4.2.2"
ARG MPC_VERSION="1.3.1"

RUN <<EOF
  cd /tmp
  wget ${GNU_MIRROR}/binutils/binutils-${BINUTILS_VERSION}.tar.gz
  tar xf binutils-${BINUTILS_VERSION}.tar.gz
  cd binutils-${BINUTILS_VERSION}
  ./configure --enable-libssp --enable-gold --enable-ld \
  --target=${FREEBSD_PREFIX} --prefix=/usr/${FREEBSD_PREFIX} --bindir=/usr/bin
  make -j4
  make install
  cd /tmp && rm -rf /tmp/*
EOF

RUN <<EOF
  cd /tmp
  wget https://mirror.aarnet.edu.au/pub/FreeBSD/releases/amd64/${FREEBSD_VERSION}-RELEASE/base.txz
  cd /usr/${FREEBSD_PREFIX}/${FREEBSD_PREFIX}
  tar -xf /tmp/base.txz ./lib/ ./usr/lib/ ./usr/include/
  cd /usr/${FREEBSD_PREFIX}/${FREEBSD_PREFIX}/usr/lib
  find . -xtype l|xargs ls -l|grep ' /lib/' \
  | awk '{print "ln -sf /usr/x86_64-pc-freebsd14/x86_64-pc-freebsd14"$11 " " $9}' \
  | /bin/sh
  cd /tmp && rm -rf /tmp/*
EOF

RUN <<EOF
  cd /tmp
  wget ${GNU_MIRROR}/gmp/gmp-${GMP_VERSION}.tar.xz
  tar -xf gmp-${GMP_VERSION}.tar.xz
  cd gmp-${GMP_VERSION}
  ./configure --prefix=/usr/${FREEBSD_PREFIX} --bindir=/usr/bin --enable-shared --enable-static \
  --enable-fft --enable-cxx --host=${FREEBSD_PREFIX}
  make -j4 && make install
  cd /tmp && rm -rf /tmp/*
EOF

RUN <<EOF
  cd /tmp
  wget ${GNU_MIRROR}/mpfr/mpfr-${MPFR_VERSION}.tar.xz && tar -xf mpfr-${MPFR_VERSION}.tar.xz
  cd mpfr-${MPFR_VERSION}
  ./configure --prefix=/usr/${FREEBSD_PREFIX} --bindir=/usr/bin --with-gnu-ld--enable-static \
  --enable-shared --with-gmp=/usr/${FREEBSD_PREFIX} --host=${FREEBSD_PREFIX}
  make -j4 && make install
  cd /tmp && rm -rf /tmp/*
EOF

RUN <<EOF
  cd /tmp
  wget ${GNU_MIRROR}/mpc/mpc-${MPC_VERSION}.tar.gz && tar -xf mpc-${MPC_VERSION}.tar.gz
  cd mpc-${MPC_VERSION}
  ./configure --prefix=/usr/${FREEBSD_PREFIX} --bindir=/usr/bin --with-gnu-ld --enable-static \
  --enable-shared --with-gmp=/usr/${FREEBSD_PREFIX} \
  --with-mpfr=/usr/${FREEBSD_PREFIX} --host=${FREEBSD_PREFIX}
  make -j4 && make install
  cd /tmp && rm -rf /tmp/*
EOF

RUN <<EOF
  cd /tmp
  wget ${GNU_MIRROR}/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz
  tar xf gcc-${GCC_VERSION}.tar.xz
  cd gcc-${GCC_VERSION}
  mkdir build
  cd build
  ../configure --without-headers --with-gnu-as --with-gnu-ld --disable-nls \
  --enable-languages=c,c++ --enable-libssp --enable-gold --enable-ld \
  --disable-libitm --disable-libquadmath --disable-multilib --target=${FREEBSD_PREFIX} \
  --prefix=/usr/${FREEBSD_PREFIX} --bindir=/usr/bin --with-gmp=/usr/${FREEBSD_PREFIX} \
  --with-mpc=/usr/${FREEBSD_PREFIX} --with-mpfr=/usr/${FREEBSD_PREFIX} --disable-libgomp \
  --with-sysroot=/usr/${FREEBSD_PREFIX}/${FREEBSD_PREFIX} \
  --with-build-sysroot=/usr/${FREEBSD_PREFIX}/${FREEBSD_PREFIX}
  cd /tmp/gcc-${GCC_VERSION}/build
  make -j4 && make install
  cd /tmp && rm -rf /tmp/*
EOF

ARG GLIBC_TRIPLES="arm-linux-gnueabihf,aarch64-linux-gnu"

RUN <<EOF
  for triple in $(echo ${GLIBC_TRIPLES} | tr "," " "); do
    for bin in /usr/bin/$triple-*; do
      if [ ! -f /usr/$triple/bin/$(basename $bin | sed "s/$triple-//") ]; then
        ln -s $bin /usr/$triple/bin/$(basename $bin | sed "s/$triple-//")
      fi
    done
    for bin in /usr/bin/$triple-*; do
      if [ ! -f /usr/$triple/bin/cc ]; then
        ln -s gcc /usr/$triple/bin/cc
      fi
    done
  done
  for triple in $(echo ${FREEBSD_PREFIX} | tr "," " "); do
    mkdir -p /usr/$triple/bin
    for bin in /usr/bin/$triple-*; do
      if [ ! -f /usr/$triple/bin/$(basename $bin | sed "s/$triple-//") ]; then
        ln -s $bin /usr/$triple/bin/$(basename $bin | sed "s/$triple-//")
      fi
    done
    ln -s gcc /usr/$triple/bin/cc
  done
EOF

ARG GO_VERSION="1.25.0"

RUN <<EOF
  cd /tmp
  wget https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz
  tar -xvf go${GO_VERSION}.linux-amd64.tar.gz
  mv go /usr/local/
  git config --global --add safe.directory /workdir
  rm -rf /tmp/*
EOF

COPY --link ./assets/crossbuild /usr/bin/crossbuild

ENTRYPOINT ["/usr/bin/crossbuild"]
CMD ["/bin/bash"]
WORKDIR /workdir
