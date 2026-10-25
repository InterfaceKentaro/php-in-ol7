FROM oraclelinux:7.7 AS base
RUN yum -y install \
    git \
    curl \
    tar \
    grep \
    gcc-c++ \
    gpg \
    make \
    bison \
    libtool \
    ccahce \
    oracle-softwarecollection-release-el7 

FROM base AS gpg

WORKDIR /gpg/libgpg-error
RUN curl -O "https://gnupg.org/ftp/gcrypt/gpgrt/libgpg-error-1.61.tar.gz" \
    && tar -xvf libgpg-error-1.61.tar.gz
WORKDIR /gpg/libgpg-error/libgpg-error-1.61/out
RUN ../configure && make && make install
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:"/gpg/libgpg-error-1.61/out/src/.libs"

WORKDIR /gpg/libgcrypt
RUN curl -O "https://gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-1.12.4.tar.gz" \
    && tar -xvf libgcrypt-1.12.4.tar.gz
WORKDIR /gpg/libgcrypt/libgcrypt-1.12.4/out
RUN yum install -y devtoolset-11-gcc devtoolset-11-binutils \
    && scl enable devtoolset-11 '../configure && make && make install'
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:"/gpg/libgcrypt/libgcrypt-1.12.4/out/src/.libs"

WORKDIR /gpg/libassuan
RUN yum install -y gzip bzip2 \
    && curl -O "https://gnupg.org/ftp/gcrypt/libassuan/libassuan-3.0.2.tar.bz2" \
    && tar -xvf "libassuan-3.0.2.tar.bz2"
WORKDIR /gpg/libassuan/libassuan-3.0.2/out
RUN ../configure && make && make install
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:"/gpg/libassuan/libassuan-3.0.2/out/src/.libs/"

WORKDIR /gpg/libksba
RUN curl -O "https://gnupg.org/ftp/gcrypt/libksba/libksba-1.8.1.tar.bz2" \
    && tar -xvf "libksba-1.8.1.tar.bz2"
WORKDIR /gpg/libksba/libksba-1.8.1/out 
RUN ../configure && make && make install
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:"/gpg/libksba/libksba-1.8.1/out/src/.libs/"

WORKDIR /gpg/npath
RUN curl -O "https://gnupg.org/ftp/gcrypt/npth/npth-1.8.tar.bz2" \
    && tar -xvf "npth-1.8.tar.bz2"
WORKDIR /gpg/npath/npth-1.8/out
RUN ../configure && make && make install
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:"/gpg/npath/npth-1.8/out/src/.libs/"

WORKDIR /gpg
ARG GPG_VER="gnupg-w32-2.5.24_20260923"
ARG GPG_NAME="gnupg-w32-2.5.24_20260923.tar.xz"
ARG GPG_URL="https://www.gnupg.org/ftp/gcrypt/gnupg"
RUN curl -O "$GPG_URL/$GPG_NAME" \
    && curl -O "$GPG_URL/$GPG_NAME.sig" \
    && curl -O "https://gnupg.org/signature_key.asc" \
    # && gpg --import signature_key.asc \
    # && gpg --verify $GPG_NAME.sig $GPG_NAME \
    && tar -xvf $GPG_NAME
WORKDIR /gpg/gnupg-w32-2.5.24/out
RUN ../configure && make && make install

FROM gpg AS c2plus 
WORKDIR /root
# This repository provides an relatively newer version of c++ compiler necessary for building gcc.
ARG OL_SOFTWARE_COL="oracle-softwarecollection-release-el7"
RUN yum install -y $OL_SOFTWARE_COL \
    && yum-config-manager --enable $OL_SOFTWARE_COL \
    && yum install -y devtoolset-11-gcc devtoolset-11-gcc-c++ devtoolset-11-binutils \
    && scl enable devtoolset-11 bash 

# install latest autoconf(>=2.7)
FROM c2plus AS autoconf
WORKDIR /autoconf
RUN yum install -y wget \
    && wget "https://ftp.gnu.org/gnu/gnu-keyring.gpg"
RUN gpg --import "gnu-keyring.gpg" || : && :
ARG AUTOCONF_VER="autoconf-2.73"
ARG AUTOCONF_NAME="autoconf-2.73.tar.xz"
ARG AUTOCONF_URL="https://ftp.gnu.org/gnu/autoconf"
RUN curl -O "$AUTOCONF_URL/$AUTOCONF_NAME" \
    && curl -O "$AUTOCONF_URL/autoconf-2.73.tar.xz.sig" \
    # && gpg --verify "autoconf-2.73.tar.xz.sig" $AUTOCONF_NAME \
    && tar -xvf $AUTOCONF_NAME 
WORKDIR /autoconf/$AUTOCONF_VER/out
RUN yum install -y autoconf \
    && ../configure && make && make install

FROM autoconf AS python
# Necessary for building re2c
WORKDIR /python3.7
RUN curl -O "https://www.python.org/ftp/python/3.7.0/Python-3.7.0.tar.xz" \
    && yum install -y gcc zlib zlib-devel libffi-devel \
    && tar -xvf Python-3.7.0.tar.xz
WORKDIR /python3.7/Python-3.7.0/out
    RUN ../configure && make -j4 && make install \
    && cp ./python /usr/bin/python3.7 \
    && rm -f /usr/bin/python \
    && ln -s /usr/bin/python3.7 /usr/bin/python

FROM python AS dep
WORKDIR /re2c
ARG RE2C_VER="re2c-4.5"
ARG RE2C_NAME="re2c-4.5.tar.xz"           
ARG RE2C_URL="https://github.com/skvadrik/re2c/releases/download/4.5"
RUN curl -O -L "$RE2C_URL/$RE2C_NAME" \
    && tar -xvf $RE2C_NAME
WORKDIR /re2c/$RE2C_VER/out
RUN scl enable devtoolset-11 '../configure && make -j4 && make install'

# GMP
WORKDIR /gmp
ARG GMP_VER="gmp-6.3.0"
ARG GMP_NAME="gmp-6.3.0.tar.xz"           
ARG GMP_URL="https://ftp.gnu.org/gnu/gmp"
RUN curl -O "$GMP_URL/$GMP_NAME" \
    && curl -O "$GMP_URL/$GMP_NAME.sig" \
    # && gpg --verify "$GMP_NAME.sig" "$GMP_NAME" \
    && tar -xvf "$GMP_NAME"
WORKDIR /gmp/$GMP_VER/out
RUN ../configure && make && make install

# MPFR
WORKDIR /mpfr
ARG MPFR_VER="mpfr-4.2.2"
ARG MPFR_NAME="mpfr-4.2.2.tar.xz"
ARG MPFR_URL="https://www.mpfr.org/mpfr-current/mpfr-4.2.2.tar.xz"
RUN curl -O "$MPFR_URL/$MPFR_NAME" \
    && curl -O "$MPFR_URL/$MPFR_NAME.asc" \
    && curl -O "https://www.vinc17.net/key.asc" \
    && curl -O "https://gnupg.org/signature_key.asc" \
    # && gpg --import "key.asc" \
    # && gpg --import "signature_key.asc" \
    # && gpg --verify "$MPFR_NAME.asc" "$MPFR_NAME" \
    && tar -xvf $MPFR_NAME
WORKDIR /mpfr/$MPFR_VER/out
RUN ../configure && make -j4 && make install
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:"/mpfr/mpfr-4.2.2/out/src/.libs/"

# MPC
WORKDIR /mpc
ARG MPC_VER="mpc-1.4.0"
ARG MPC_NAME="mpc-1.4.0.tar.xz"
ARG MPC_URL="https://www.multiprecision.org/downloads"
WORKDIR /mpc
RUN curl -O "$MPC_URL/$MPC_NAME" \
    && curl -O "$MPC_URL/$MPC_NAME.sig" \
    # && gpg --verify "$MPC_NAME.sig" "$MPC_NAME" \
    && tar -xvf $MPC_NAME
WORKDIR /mpc/$MPC_VER/out
RUN ../configure && make && make install

# gcc
FROM dep AS gcc
WORKDIR /gcc
ARG GCC_VER="gcc-16.2.0"
ARG GCC_NAME="gcc-16.2.0.tar.xz"
ARG GCC_URL="https://mirror.marwan.ma/gcc/releases/gcc-16.2.0"
RUN curl -O "$GCC_URL/sha512.sum" \
    && curl -O "$GCC_URL/$GCC_NAME" \
    && grep -ie "$GCC_NAME$" "sha512.sum" > "sha512_ex.sum" \
    && sha512sum "$GCC_NAME" \
    && sha512sum -c "sha512_ex.sum" \
    && tar -xvf $GCC_NAME
WORKDIR /gcc/$GCC_VER/out
RUN scl enable devtoolset-11 '../configure --disable-multilib && make -j4 && make install'
ENV PATH=$PATH:'/usr/local/bin/'

FROM gcc AS php
WORKDIR /php-src
RUN git clone -b PHP-8.1-CVE-2026-109618-109619 "https://github.com/php/php-src.git" .
WORKDIR /php-src/out
RUN ../buildconf --force && ../configure --disable-all
RUN make && make install

