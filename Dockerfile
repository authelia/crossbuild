FROM buildpack-deps:stretch-curl
LABEL maintainer="Nightah"

ENV CROSS_TRIPLE="x86_64-linux-gnu" \
    PATH="/root/go/bin:/usr/local/go/bin:$PATH" \
    LD_LIBRARY_PATH="/usr/x86_64-pc-freebsd13/lib:$LD_LIBRARY_PATH" \
    GOROOT="/usr/local/go" \
    CGO_CPPFLAGS="-D_FORTIFY_SOURCE=2 -fstack-protector-strong" \
    CGO_LDFLAGS="-Wl,-z,relro,-z,now"

# Install deps
RUN set -x; echo "Starting image build for Debian Bullseye" \
 && dpkg --add-architecture arm64                      \
 && dpkg --add-architecture armhf                      \
 && apt-get update                                     \
 && apt-get install -y -q                              \
        autoconf                                       \
        automake                                       \
        autotools-dev                                  \
        binutils-multiarch                             \
        binutils-multiarch-dev                         \
        build-essential                                \
        ccache                                         \
        crossbuild-essential-arm64                     \
        crossbuild-essential-armhf                     \
        curl                                           \
        git-core                                       \
        multistrap                                     \
        wget                                           \
        xz-utils                                       \
        libxml2-dev                                    \
        lzma-dev                                       \
        openssl                                        \
        libssl-dev                                     \
 && apt-get clean

# Latest is 13.1
ARG FREEBSD_VERSION="13.0"

# Latest is 2.40
ARG BINUTILS_VERSION="2.37"

ARG GMP_VERSION="6.2.1"

# Latest is 4.2.0
ARG MPFR_VERSION="4.1.0"

# Latest is 1.3.1
ARG MPC_VERSION="1.2.1"

# Latest is 11.3.0 / 12.2.0
ARG GCC_VERSION="11.1.0"
# Install FreeBSD cross-tools
# Compile binutils
RUN cd /tmp && \
  wget https://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.gz && \
  tar xf binutils-${BINUTILS_VERSION}.tar.gz && \
  cd binutils-${BINUTILS_VERSION} && \
  ./configure --enable-libssp --enable-gold --enable-ld \
  --target=x86_64-pc-freebsd13 --prefix=/usr/x86_64-pc-freebsd13 --bindir=/usr/bin && \
  make -j4 && \
  make install && \
  cd /tmp && rm -rf /tmp/*
# Get FreeBSD libs/headers
RUN cd /tmp && \
  wget https://mirror.aarnet.edu.au/pub/FreeBSD/releases/amd64/${FREEBSD_VERSION}-RELEASE/base.txz && \
  cd /usr/x86_64-pc-freebsd13/x86_64-pc-freebsd13 && \
  tar -xf /tmp/base.txz ./lib/ ./usr/lib/ ./usr/include/ && \
  cd /usr/x86_64-pc-freebsd13/x86_64-pc-freebsd13/usr/lib && \
  find . -xtype l|xargs ls -l|grep ' /lib/' \
  | awk '{print "ln -sf /usr/x86_64-pc-freebsd13/x86_64-pc-freebsd13"$11 " " $9}' \
  | /bin/sh && \
  cd /tmp && rm -rf /tmp/*
# Compile GMP
RUN cd /tmp && \
  wget https://ftp.gnu.org/gnu/gmp/gmp-${GMP_VERSION}.tar.xz && \
  tar -xf gmp-${GMP_VERSION}.tar.xz && \
  cd gmp-${GMP_VERSION} && \
  ./configure --prefix=/usr/x86_64-pc-freebsd13 --bindir=/usr/bin --enable-shared --enable-static \
  --enable-fft --enable-cxx --host=x86_64-pc-freebsd13 && \
  make -j4 && make install && \
  cd /tmp && rm -rf /tmp/*
# Compile MPFR
RUN cd /tmp && \
  wget https://ftp.gnu.org/gnu/mpfr/mpfr-${MPFR_VERSION}.tar.xz && tar -xf mpfr-${MPFR_VERSION}.tar.xz && \
  cd mpfr-${MPFR_VERSION} && \
  ./configure --prefix=/usr/x86_64-pc-freebsd13 --bindir=/usr/bin --with-gnu-ld--enable-static \
  --enable-shared --with-gmp=/usr/x86_64-pc-freebsd13 --host=x86_64-pc-freebsd13 && \
  make -j4 && make install && \
  cd /tmp && rm -rf /tmp/*
# Compile MPC
RUN cd /tmp && \
  wget https://ftp.gnu.org/gnu/mpc/mpc-${MPC_VERSION}.tar.gz && tar -xf mpc-${MPC_VERSION}.tar.gz && \
  cd mpc-${MPC_VERSION} && \
  ./configure --prefix=/usr/x86_64-pc-freebsd13 --bindir=/usr/bin --with-gnu-ld --enable-static \
  --enable-shared --with-gmp=/usr/x86_64-pc-freebsd13 \
  --with-mpfr=/usr/x86_64-pc-freebsd13 --host=x86_64-pc-freebsd13 && \
  make -j4 && make install && \
  cd /tmp && rm -rf /tmp/*
# Compile GCC
RUN cd /tmp && \
  wget https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz && \
  tar xf gcc-${GCC_VERSION}.tar.xz && \
  cd gcc-${GCC_VERSION} && mkdir build && cd build && \
  ../configure --without-headers --with-gnu-as --with-gnu-ld --disable-nls \
  --enable-languages=c,c++ --enable-libssp --enable-gold --enable-ld \
  --disable-libitm --disable-libquadmath --disable-multilib --target=x86_64-pc-freebsd13 \
  --prefix=/usr/x86_64-pc-freebsd13 --bindir=/usr/bin --with-gmp=/usr/x86_64-pc-freebsd13 \
  --with-mpc=/usr/x86_64-pc-freebsd13 --with-mpfr=/usr/x86_64-pc-freebsd13 --disable-libgomp \
  --with-sysroot=/usr/x86_64-pc-freebsd13/x86_64-pc-freebsd13 \
  --with-build-sysroot=/usr/x86_64-pc-freebsd13/x86_64-pc-freebsd13 && \
  cd /tmp/gcc-${GCC_VERSION} && \
  cd /tmp/gcc-${GCC_VERSION}/build && \
  make -j4 && make install && \
  cd /tmp && rm -rf /tmp/*

ARG LINUX_TRIPLES="arm-linux-gnueabihf,aarch64-linux-gnu"
ARG FREEBSD_TRIPLES="x86_64-pc-freebsd13"
# Create symlinks for triples
RUN for triple in $(echo ${LINUX_TRIPLES} | tr "," " "); do                                       \
      for bin in /usr/bin/$triple-*; do                                                           \
        if [ ! -f /usr/$triple/bin/$(basename $bin | sed "s/$triple-//") ]; then                  \
          ln -s $bin /usr/$triple/bin/$(basename $bin | sed "s/$triple-//");                      \
        fi;                                                                                       \
      done;                                                                                       \
      for bin in /usr/bin/$triple-*; do                                                           \
        if [ ! -f /usr/$triple/bin/cc ]; then                                                     \
          ln -s gcc /usr/$triple/bin/cc;                                                          \
        fi;                                                                                       \
      done;                                                                                       \
    done &&                                                                                       \
    for triple in $(echo ${FREEBSD_TRIPLES} | tr "," " "); do                                     \
      mkdir -p /usr/$triple/bin;                                                                  \
      for bin in /usr/bin/$triple-*; do                                                           \
        if [ ! -f /usr/$triple/bin/$(basename $bin | sed "s/$triple-//") ]; then                  \
          ln -s $bin /usr/$triple/bin/$(basename $bin | sed "s/$triple-//");                      \
        fi;                                                                                       \
      done;                                                                                       \
      ln -s gcc /usr/$triple/bin/cc;                                                              \
    done

ARG GO_VERSION="1.21.1"
# Install Golang and gox
RUN cd /tmp && \
  wget https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz && \
  tar -xvf go${GO_VERSION}.linux-amd64.tar.gz && \
  mv go /usr/local/ && \
  go install github.com/authelia/gox@latest && \
  rm -rf /tmp/*

# Image metadata
ENTRYPOINT ["/usr/bin/crossbuild"]
CMD ["/bin/bash"]
WORKDIR /workdir
COPY ./assets/crossbuild /usr/bin/crossbuild
