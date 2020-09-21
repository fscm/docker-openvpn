# global args
ARG __BUILD_DIR__="/build"
ARG __DATA_DIR__="/data"
ARG __EASYRSA_DATA_DIR__="${__DATA_DIR__}/easyrsa"
ARG __OPENVPN_DATA_DIR__="${__DATA_DIR__}/openvpn"


FROM fscm/debian:buster as build

ARG __BUILD_DIR__
ARG __DATA_DIR__
ARG __EASYRSA_DATA_DIR__
ARG EASYRSA_VERSION="3.0.8"
ARG EASYRSA_REQ_CITY="Lisboa"
ARG EASYRSA_REQ_COUNTRY="PT"
ARG EASYRSA_REQ_EMAIL="private"
ARG EASYRSA_REQ_ORG="Private Company"
ARG EASYRSA_REQ_OU="IT"
ARG EASYRSA_REQ_PROVINCE="Lisboa"
ARG IPTABLES_VERSION="1.8.5"
ARG KERNEL_VERSION="5.8.7"
ARG LIBFFI_VERSION="3.3"
ARG LIBPCAP_VERSION="1.9.1"
ARG LIBTASN1_VERSION="4.16.0"
ARG LZ4_VERSION="1.9.2"
ARG LZO_VERSION="2.10"
ARG OPENSSL_VERSION="1.1.1g"
ARG OPENVPN_VERSION="2.4.9"
ARG P11KIT_VERSION="0.23.21"
ARG PKCS11HELPER_VERSION="1.26.0"
ARG __USER__="root"
ARG __WORK_DIR__="/work"
ARG __SOURCE_DIR__="${__WORK_DIR__}/src"

ENV \
  LANG="C.UTF-8" \
  LC_ALL="C.UTF-8" \
  DEBCONF_NONINTERACTIVE_SEEN="true" \
  DEBIAN_FRONTEND="noninteractive"

COPY "LICENSE" "files/" "${__WORK_DIR__}"/
COPY --from=busybox:uclibc "/bin/busybox" "${__WORK_DIR__}"/

WORKDIR "${__WORK_DIR__}"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN \
# build env
  echo '=== setting build env ===' && \
  time { \
    set +h && \
    export __NPROC__="$(getconf _NPROCESSORS_ONLN || echo 1)" && \
    export MAKEFLAGS="--silent --output-sync --no-print-directory --jobs ${__NPROC__} V=0" && \
    export PKG_CONFIG_PATH="/usr/lib/x86_64-linux-musl/pkgconfig" && \
    export TIMEFORMAT='=== time taken: %lR' ; \
  } && \
# build structure
  echo '=== creating build structure ===' && \
  time { \
    for folder in 'bin' 'sbin'; do \
      install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/usr/${folder}"; \
      ln --symbolic "usr/${folder}" "${__BUILD_DIR__}/${folder}"; \
    done && \
    for folder in 'include' 'lib'; do \
      ln --symbolic "/usr/${folder}/x86_64-linux-musl" "${__BUILD_DIR__}/usr/${folder}"; \
    done && \
    for folder in '/tmp' "${__DATA_DIR__}"; do \
      install --directory --owner="${__USER__}" --group="${__USER__}" --mode=1777 "${__BUILD_DIR__}${folder}"; \
    done ; \
  } && \
# copy tests
  echo '=== copying test files ===' && \
  time { \
    install --owner="${__USER__}" --group="${__USER__}" --mode=0755 --target-directory="${__BUILD_DIR__}/usr/bin" "${__WORK_DIR__}/tests"/* ; \
  } && \
# copy scripts
  echo '=== copying script files ===' && \
  time { \
    install --owner="${__USER__}" --group="${__USER__}" --mode=0755 --target-directory="${__BUILD_DIR__}/usr/bin" "${__WORK_DIR__}/scripts"/* ; \
  } && \
# dependencies
  echo '=== instaling dependencies ===' && \
  time { \
    apt-get -qq update && \
    apt-get -qq -y -o=Dpkg::Use-Pty=0 --no-install-recommends install \
      bison \
      bzip2 \
      ca-certificates \
      curl \
      file \
      flex \
      gcc \
      make \
      musl-tools \
      openssl \
      perl \
      pkg-config \
      rsync \
      xz-utils \
      zlib1g-dev \
      > /dev/null 2>&1 ; \
  } && \
# kernel headers
  echo '=== installing kernel headers ===' && \
  time { \
    install --directory "${__SOURCE_DIR__}/kernel" && \
    curl --silent --location --retry 3 "https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_VERSION%%.*}.x/linux-${KERNEL_VERSION}.tar.xz" \
      | tar xJ --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/kernel" --wildcards "*LICENSE*" "*COPYING*" $(echo linux-*/{Makefile,arch,include,scripts,tools,usr}) && \
    cd "${__SOURCE_DIR__}/kernel" && \
    make INSTALL_HDR_PATH="./_headers" headers_install > /dev/null && \
    cp --recursive './_headers/include'/*  '/usr/include/x86_64-linux-musl/' && \
    cd ~- && \
    rm -rf "${__SOURCE_DIR__}/kernel" ; \
  } && \
# openssl 
  echo '=== installing openssl ===' && \
  time { \
    install --directory "${__SOURCE_DIR__}/openssl/_build" && \
    curl --silent --location --retry 3 "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz" \
      | tar xz --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/openssl" && \
    cd "${__SOURCE_DIR__}/openssl/_build" && \
    ../config \
      CC="musl-gcc -static --static --sysroot='${__BUILD_DIR__}'" \
      --libdir='/usr/lib' \
      --openssldir='/etc/ssl' \
      --prefix='/usr' \
      --release \
      --static \
      enable-cms \
      enable-ec_nistp_64_gcc_128 \
      enable-rfc3779 \
      no-comp \
      no-shared \
      no-ssl3 \
      no-weak-ssl-ciphers \
      no-zlib \
      -pipe \
      -static \
      -DNDEBUG \
      -DOPENSSL_NO_HEARTBEATS && \
    make > /dev/null && \
    make DESTDIR="${__BUILD_DIR__}" install_sw > /dev/null && \
    make DESTDIR="${__BUILD_DIR__}" install_ssldirs > /dev/null && \
    rm -rf "${__BUILD_DIR__}/etc/ssl/misc" && \
    rm -rf "${__BUILD_DIR__}/usr/bin/c_rehash" && \
    find "${__BUILD_DIR__}/etc" -type f -name '*.dist' -delete && \
    install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/licenses/openssl" && \
    (cd .. && find ./ -type f -a \( -name '*LICENSE*' -o -name '*COPYING*' \) -exec cp --parents {} "${__BUILD_DIR__}/licenses/openssl" ';') && \
    cd ~- && \
    rm -rf "${__SOURCE_DIR__}/openssl" ; \
  } && \
# libpcap
  echo '=== installing libpcap ===' && \
  time { \
    install --directory "${__SOURCE_DIR__}/libpcap/_build" && \
    curl --silent --location --retry 3 "https://www.tcpdump.org/release/libpcap-${LIBPCAP_VERSION}.tar.gz" \
      | tar xz --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/libpcap" && \
    cd "${__SOURCE_DIR__}/libpcap/_build" && \
    for file in $(find ../ -name 'Makefile.in'); do \
      sed -i.orig \
        -e '/^MAN.* =/ s/=.*/=/' -e '/^MAN.* =/,/^$/{//!d}' \
        -e '/(cd.*man3 &&/,/(LN_S) pcap_setnonblock.3pcap pcap_getnonblock.3pcap/d' \
        -e '/-d.*mandir/,/mkdir.*mandir/d' "${file}"; \
    done && \
    ../configure \
      CC="musl-gcc -static --static --sysroot='${__BUILD_DIR__}'" \
      --quiet \
      --includedir='/usr/include' \
      --libdir='/usr/lib' \
      --libexecdir='/usr/libexec' \
      --prefix='/usr' \
      --sysconfdir='/etc' \
      --enable-ipv6 \
      --disable-shared && \
    make > /dev/null && \
    make DESTDIR="${__BUILD_DIR__}" install > /dev/null && \
    install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/licenses/libpcap" && \
    (cd .. && find ./ -type f -a \( -name '*LICENSE*' -o -name '*COPYING*' \) -exec cp --parents {} "${__BUILD_DIR__}/licenses/libpcap" ';') && \
    cd ~- && \
    rm -rf "${__SOURCE_DIR__}/libpcap" ; \
  } && \
# iptables
  echo '=== installing iptables ===' && \
  time { \
    install --directory "${__SOURCE_DIR__}/iptables/_build" && \
    curl --silent --location --retry 3 "https://www.netfilter.org/projects/iptables/files/iptables-${IPTABLES_VERSION}.tar.bz2" \
      | tar xj --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/iptables" && \
    cd "${__SOURCE_DIR__}/iptables/_build" && \
    for file in $(find ../ -name 'Makefile.in'); do \
      sed -i.orig -e '/^install-man[0-9]*:/ s/:.*/:/' -e '/^install-man[0-9]*:/,/^$/{//!d}' "${file}"; \
    done && \
    ../configure \
      CC="musl-gcc -static --static --sysroot='${__BUILD_DIR__}'" \
      --quiet \
      --includedir='/usr/include' \
      --libdir='/usr/lib' \
      --libexecdir='/usr/libexec' \
      --prefix='/usr' \
      --sysconfdir='/etc' \
      --with-xtlibdir='/usr/libexec/xtables' \
      --enable-bpf-compiler \
      --enable-devel \
      --enable-libipq \
      --enable-nfsynproxy \
      --enable-static \
      --disable-connlabel \
      --disable-nftables \
      --disable-shared && \
    make > /dev/null && \
    make DESTDIR="${__BUILD_DIR__}" install > /dev/null && \
    install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/licenses/iptables" && \
    (cd .. && find ./ -type f -a \( -name '*LICENSE*' -o -name '*COPYING*' \) -exec cp --parents {} "${__BUILD_DIR__}/licenses/iptables" ';') && \
    cd ~- && \
    rm -rf "${__SOURCE_DIR__}/iptables" ; \
  } && \
# lzo
  echo '=== installing lzo ===' && \
  time { \
    install --directory "${__SOURCE_DIR__}/lzo/_build" && \
    curl --silent --location --retry 3 "http://www.oberhumer.com/opensource/lzo/download/lzo-${LZO_VERSION}.tar.gz" \
      | tar xz --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/lzo" && \
    cd "${__SOURCE_DIR__}/lzo/_build" && \
    sed -i.orig -e '/^docdir =/ s/=.*/=/' -e '/^doc_DATA =/ s/=.*/=/' ../Makefile.in && \
    ../configure \
      CC="musl-gcc -static --static --sysroot='${__BUILD_DIR__}'" \
      --quiet \
      --includedir='/usr/include' \
      --libdir='/usr/lib' \
      --libexecdir='/usr/libexec' \
      --prefix='/usr' \
      --sysconfdir='/etc' \
      --enable-fast-install \
      --enable-silent-rules \
      --enable-static \
      --disable-shared && \
    make > /dev/null && \
    make DESTDIR="${__BUILD_DIR__}" install > /dev/null && \
    install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/licenses/lzo" && \
    (cd .. && find ./ -type f -a \( -name '*LICENSE*' -o -name '*COPYING*' \) -exec cp --parents {} "${__BUILD_DIR__}/licenses/lzo" ';') && \
    cd ~- && \
    rm -rf "${__SOURCE_DIR__}/lzo" ; \
  } && \
# lz4
  echo '=== installing lz4 ===' && \
  time { \
    install --directory "${__SOURCE_DIR__}/lz4" && \
    curl --silent --location --retry 3 "https://github.com/lz4/lz4/archive/v${LZ4_VERSION}.tar.gz" \
      | tar xz --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/lz4" && \
    cd "${__SOURCE_DIR__}/lz4" && \
    sed -i.orig -e '/^man1dir/ s/=.*/=/' -e '/@echo Installing man pages/,/@echo lz4 installation completed/{//!d}' ./programs/Makefile && \
    make CC="musl-gcc -static --static --sysroot='${__BUILD_DIR__}'" PREFIX='/usr' BUILD_SHARED='no' > /dev/null && \
    make DESTDIR="${__BUILD_DIR__}" PREFIX='/usr' BUILD_SHARED='no' install > /dev/null && \
    install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/licenses/lz4" && \
    (find ./ -type f -a \( -name '*LICENSE*' -o -name '*COPYING*' \) -exec cp --parents {} "${__BUILD_DIR__}/licenses/lz4" ';') && \
    cd ~- && \
    rm -rf "${__SOURCE_DIR__}/lz4" ; \
  } && \
# libtasn1
  echo '=== installing libtasn1 ===' && \
  time { \
    install --directory "${__SOURCE_DIR__}/libtasn1/_build" && \
    curl --silent --location --retry 3 "https://ftp.gnu.org/gnu/libtasn1/libtasn1-${LIBTASN1_VERSION}.tar.gz" \
      | tar xz --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/libtasn1" && \
    cd "${__SOURCE_DIR__}/libtasn1/_build" && \
    for file in $(find ../ -name 'Makefile.in'); do \
      sed -i.orig \
        -e '/^install-man[0-9]*:/ s/:.*/:/' -e '/^install-man[0-9]*:/,/^$/{//!d}' \
        -e '/^install-info.*:/ s/:.*/:/' -e '/^install-info.*:/,/^$/{//!d}' "${file}"; \
    done && \
    ../configure \
      CC="musl-gcc -static --static --sysroot='${__BUILD_DIR__}'" \
      --quiet \
      --includedir='/usr/include' \
      --libdir='/usr/lib' \
      --libexecdir='/usr/libexec' \
      --prefix='/usr' \
      --sysconfdir='/etc' \
      --enable-fast-install \
      --enable-silent-rules \
      --enable-static \
      --disable-gtk-doc \
      --disable-gtk-doc-html \
      --disable-gtk-doc-pdf \
      --disable-shared && \
    make > /dev/null && \
    make DESTDIR="${__BUILD_DIR__}" install > /dev/null && \
    install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/licenses/libtasn1" && \
    (cd .. && find ./ -type f -a \( -name '*LICENSE*' -o -name '*COPYING*' \) -exec cp --parents {} "${__BUILD_DIR__}/licenses/libtasn1" ';') && \
    cd ~- && \
    rm -rf "${__SOURCE_DIR__}/libtasn1" ; \
  } && \
# libffi
  echo '=== installing libffi ===' && \
  time { \
    install --directory "${__SOURCE_DIR__}/libffi/_build" && \
    curl --silent --location --retry 3 "https://sourceware.org/pub/libffi/libffi-${LIBFFI_VERSION}.tar.gz" \
      | tar xz --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/libffi" && \
    cd "${__SOURCE_DIR__}/libffi/_build" && \
    for file in $(find ../ -name 'Makefile.in'); do \
      sed -i.orig -e '/^install-man[0-9]*:/ s/:.*/:/' -e '/^install-man[0-9]*:/,/^$/{//!d}' "${file}"; \
    done && \
    ../configure \
      CC="musl-gcc -static --static --sysroot='${__BUILD_DIR__}'" \
      --quiet \
      --includedir='/usr/include' \
      --libdir='/usr/lib' \
      --libexecdir='/usr/libexec' \
      --prefix='/usr' \
      --sysconfdir='/etc' \
      --enable-fast-install \
      --enable-pax_emutramp \
      --enable-silent-rules \
      --enable-static \
      --disable-docs \
      --disable-multi-os-directory \
      --disable-shared && \
    make > /dev/null && \
    make DESTDIR="${__BUILD_DIR__}" install > /dev/null && \
    install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/licenses/libffi" && \
    (cd .. && find ./ -type f -a \( -name '*LICENSE*' -o -name '*COPYING*' \) -exec cp --parents {} "${__BUILD_DIR__}/licenses/libffi" ';') && \
    cd ~- && \
    rm -rf "${__SOURCE_DIR__}/libffi" ; \
  } && \
# p11-kit
  echo '=== installing p11-kit ===' && \
  time { \
    install --directory "${__SOURCE_DIR__}/p11-kit/_build" && \
    curl --silent --location --retry 3 "https://github.com/p11-glue/p11-kit/releases/download/${P11KIT_VERSION}/p11-kit-${P11KIT_VERSION}.tar.xz" \
      | tar xJ --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/p11-kit" && \
    cd "${__SOURCE_DIR__}/p11-kit/_build" && \
    ../configure \
      CC="musl-gcc -static --static --sysroot='${__BUILD_DIR__}'" \
      PKG_CONFIG_PATH="/usr/lib/x86_64-linux-musl/pkgconfig" \
      --quiet \
      --datadir='/usr/libexec' \
      --includedir='/usr/include' \
      --libdir='/usr/lib' \
      --libexecdir='/usr/libexec' \
      --prefix='/usr' \
      --sysconfdir='/etc' \
      --with-hash-impl=internal \
      --with-trust-paths="/etc/ssl/certs" \
      --without-bash-completion \
      --without-systemd \
      --enable-fast-install \
      --enable-silent-rules \
      #--enable-static \
      --disable-doc \
      --disable-doc-html \
      #--disable-shared \
      --disable-nls && \
    make > /dev/null && \
    make DESTDIR="${__BUILD_DIR__}" install > /dev/null && \
    ln --symbolic --force "/usr/libexec/p11-kit/trust-extract-compat" "${__BUILD_DIR__}/usr/bin/update-ca-certificates" && \
    install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/licenses/p11-kit" && \
    (cd .. && find ./ -type f -a \( -name '*LICENSE*' -o -name '*COPYING*' \) -exec cp --parents {} "${__BUILD_DIR__}/licenses/p11-kit" ';') && \
    cd ~- && \
    rm -rf "${__SOURCE_DIR__}/p11-kit" ; \
  } && \
# pkcs11-helper
  echo '=== installing pkcs11-helper ===' && \
  time { \
    install --directory "${__SOURCE_DIR__}/pkcs11-helper/_build" && \
    curl --silent --location --retry 3 "https://github.com/OpenSC/pkcs11-helper/releases/download/pkcs11-helper-${PKCS11HELPER_VERSION%.*}/pkcs11-helper-${PKCS11HELPER_VERSION}.tar.bz2" \
      | tar xj --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/pkcs11-helper" && \
    cd "${__SOURCE_DIR__}/pkcs11-helper/_build" && \
    for file in $(find ../ -name 'Makefile.in'); do \
      sed -i.orig \
        -e '/^install-man[0-9]*:/ s/:.*/:/' -e '/^install-man[0-9]*:/,/^$/{//!d}' \
        -e '/^dist_m4_DATA =/ s/=.*/=/' \
        -e '/^dist_doc_DATA =/ s/=.*/=/' "${file}"; \
    done && \
    ../configure \
      CC="musl-gcc -static --static --sysroot='${__BUILD_DIR__}'" \
      --quiet \
      --includedir='/usr/include' \
      --libdir='/usr/lib' \
      --libexecdir='/usr/libexec' \
      --prefix='/usr' \
      --sysconfdir='/etc' \
      --enable-fast-install \
      --enable-silent-rules \
      --enable-static \
      --disable-debug \
      --disable-doc \
      --disable-shared && \
    make > /dev/null && \
    make DESTDIR="${__BUILD_DIR__}" install > /dev/null && \
    install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/licenses/pkcs11-helper" && \
    (cd .. && find ./ -type f -a \( -name '*LICENSE*' -o -name '*COPYING*' \) -exec cp --parents {} "${__BUILD_DIR__}/licenses/pkcs11-helper" ';') && \
    cd ~- && \
    rm -rf "${__SOURCE_DIR__}/pkcs11-helper" ; \
  } && \
# busybox
  echo '=== installing busybox ===' && \
  time { \
    install --owner="${__USER__}" --group="${__USER__}" --mode=0755 --target-directory="${__BUILD_DIR__}/usr/bin" "${__WORK_DIR__}/busybox" && \
    install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/licenses/busybox" && \
    curl --silent --location --retry 3 "https://busybox.net/downloads/busybox-$(${__BUILD_DIR__}/usr/bin/busybox --help | head -1 | sed -E -n -e 's/.*v([0-9\.]+) .*/\1/p').tar.bz2" \
      | tar xj --no-same-owner --strip-components=1 -C "${__BUILD_DIR__}/licenses/busybox" --wildcards '*LICENSE*' && \
    for p in [ arp awk basename cat chmod cp cut date diff dirname du env getopt grep gzip hostname id ifconfig ip ipaddr iptunnel kill killall less ln ls mkdir mknod mktemp more mv nameif netstat pgrep ping printf ps pwd rm route sed sh slattach sort stty sysctl tar tr wget; do \
      ln "${__BUILD_DIR__}/usr/bin/busybox" "${__BUILD_DIR__}/$(${__BUILD_DIR__}/usr/bin/busybox --list-full | sed 's/$/ /' | grep -F "/${p} " | sed 's/ $//')"; \
    done && \
    ln --symbolic --force "${__BUILD_DIR__}/usr/bin/busybox" "/usr/sbin/ip"; \
  } && \
# openvpn
  echo '=== installing openvpn ===' && \
  time { \
    install --directory "${__SOURCE_DIR__}/openvpn/_build" && \
    curl --silent --location --retry 3 "https://swupdate.openvpn.org/community/releases/openvpn-${OPENVPN_VERSION}.tar.xz" \
      | tar xJ --no-same-owner --strip-components=1 -C "${__SOURCE_DIR__}/openvpn" && \
    cd "${__SOURCE_DIR__}/openvpn/_build" && \
    sed -i.orig -e 's/libcrypto >= 0.9.8, libssl >= 0.9.8/openssl >= 0.9.8/g' ../configure && \
    for file in $(find ../ -name 'Makefile.in'); do \
      sed -i.orig \
        -e '/^install-man[0-9]*:/ s/:.*/:/' -e '/^install-man[0-9]*:/,/^$/{//!d}' \
        -e '/\(^\|@\)dist_doc_DATA = \\/,/^$/{//!d}' -e '/\(^\|@\)dist_doc_DATA =/ s/=.*/=/' \
        -e '/^am__dist_doc_DATA_DIST =/ s/=.*/=/' "${file}"; \
    done && \
    ../configure \
      CC="musl-gcc -static --static --sysroot='${__BUILD_DIR__}'" \
      IPROUTE=/usr/sbin/ip \
      TMPFILES_DIR="/tmp" \
      --quiet \
      --includedir='/usr/include' \
      --libdir='/usr/lib' \
      --libexecdir='/usr/libexec' \
      --prefix='/usr' \
      --sysconfdir='/etc' \
      --with-crypto-library=openssl \
      --enable-async-push \
      --enable-crypto \
      --enable-fast-install \
      --enable-iproute2 \
      --enable-lz4 \
      --enable-lzo \
      --enable-pkcs11 \
      --enable-silent-rules \
      --enable-static \
      --enable-x509-alt-username \
      --disable-debug \
      --disable-plugin-auth-pam \
      --disable-selinux \
      --disable-shared \
      --disable-systemd && \
    make > /dev/null && \
    make DESTDIR="${__BUILD_DIR__}" install > /dev/null && \
    install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/licenses/openvpn" && \
    (cd .. && find ./ -type f -a \( -name '*LICENSE*' -o -name '*COPYING*' \) -exec cp --parents {} "${__BUILD_DIR__}/licenses/openvpn" ';') && \
    cd ~- && \
    rm -rf "${__SOURCE_DIR__}/openvpn" ; \
  } && \
# easyrsa
  echo '=== installing easyrsa ===' && \
  time { \
    install --directory "${__BUILD_DIR__}/usr/local/easyrsa" && \
    curl --silent --location --retry 3 "https://github.com/OpenVPN/easy-rsa/releases/download/v${EASYRSA_VERSION}/EasyRSA-${EASYRSA_VERSION}.tgz" \
      | tar xz --no-same-owner --strip-components=1 -C "${__BUILD_DIR__}/usr/local/easyrsa" --exclude="doc" && \
    install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/licenses/easyrsa" && \
    (cd "${__BUILD_DIR__}/usr/local/easyrsa" && find ./ -type f -a \( -name '*LICENSE*' -o -name '*COPYING*' -o -name '*gpl*' \) -exec cp --parents {} "${__BUILD_DIR__}/licenses/easyrsa" ';') && \
    find "${__BUILD_DIR__}/usr/local/easyrsa" -type f -a \( -name '*.txt' -o -name '*.md' -o -name '*ChangeLog*' \) -delete && \
    sed \
      -e "/set_var EASYRSA\t/ {s/^#//;s|\".*\"|\"${__EASYRSA_DATA_DIR__}\"|;}" \
      -e '/set_var EASYRSA_OPENSSL.*"openssl"$/ s/^#//' \
      -e "/set_var EASYRSA_PKI\t/ {s/^#//;s|\".*\"|\"${__EASYRSA_DATA_DIR__}/pki\"|;}" \
      -e "/set_var EASYRSA_REQ_COUNTRY\t/ {s/^#//;s/\".*\"/\"${EASYRSA_REQ_COUNTRY}\"/;}" \
      -e "/set_var EASYRSA_REQ_PROVINCE\t/ {s/^#//;s/\".*\"/\"${EASYRSA_REQ_PROVINCE}\"/;}" \
      -e "/set_var EASYRSA_REQ_CITY\t/ {s/^#//;s/\".*\"/\"${EASYRSA_REQ_CITY}\"/;}" \
      -e "/set_var EASYRSA_REQ_ORG\t/ {s/^#//;s/\".*\"/\"${EASYRSA_REQ_ORG}\"/;}" \
      -e "/set_var EASYRSA_REQ_EMAIL\t/ {s/^#//;s/\".*\"/\"${EASYRSA_REQ_EMAIL}\"/;}" \
      -e "/set_var EASYRSA_REQ_OU\t/ {s/^#//;s/\".*\"/\"${EASYRSA_REQ_OU}\"/;}" \
      -e '/set_var EASYRSA_KEY_SIZE\t/ {s/^#//;s/\(.*[[:space:]]\).*/\12048/;}' \
      -e '/set_var EASYRSA_ALGO\t/ {s/^#//;s/\(.*[[:space:]]\).*/\1rsa/;}' \
      -e '/set_var EASYRSA_CA_EXPIRE\t/ {s/^#//;s/\(.*[[:space:]]\).*/\13650/;}' \
      -e '/set_var EASYRSA_CERT_EXPIRE\t/ {s/^#//;s/\(.*[[:space:]]\).*/\13650/;}' \
      -e '/set_var EASYRSA_DIGEST\t/ {s/^#//;s/".*"/"sha256"/;}' \
      "${__BUILD_DIR__}/usr/local/easyrsa/vars.example" \
      > "${__BUILD_DIR__}/usr/local/easyrsa/vars" && \
    ln --symbolic "/usr/local/easyrsa/easyrsa" "${__BUILD_DIR__}/usr/bin/easyrsa" ; \
  } && \
# mozilla root certificates
  echo '=== installing root certificates ===' && \
  time { \
    install --directory "${__SOURCE_DIR__}/certificates/certs" && \
    curl --silent --location --retry 3 "https://github.com/mozilla/gecko-dev/raw/master/security/nss/lib/ckfw/builtins/certdata.txt" \
      --output "${__SOURCE_DIR__}/certificates/certdata.txt" && \
    cd "${__SOURCE_DIR__}/certificates" && \
    for cert in $(sed -n -e '/^# Certificate/=' "${__SOURCE_DIR__}/certificates/certdata.txt"); do \
      awk "NR==${cert},/^CKA_TRUST_STEP_UP_APPROVED/" "${__SOURCE_DIR__}/certificates/certdata.txt" > "${__SOURCE_DIR__}/certificates/certs/${cert}.tmp"; \
    done && \
    for file in "${__SOURCE_DIR__}/certificates/certs/"*.tmp; do \
      _cert_name_=$(sed -n -e '/^# Certificate/{s/ /_/g;s/.*"\(.*\)".*/\1/p}' "${file}"); \
      printf '%b' $(awk '/^CKA_VALUE/{flag=1;next}/^END/{flag=0}flag{printf $0}' "${file}") \
        | openssl x509 -inform DER -outform PEM -out "${__SOURCE_DIR__}/certificates/certs/${_cert_name_}.pem"; \
    done && \
    install --owner="${__USER__}" --group="${__USER__}" --mode=0644 --target-directory="${__BUILD_DIR__}/etc/ssl/certs" "${__SOURCE_DIR__}/certificates/certs"/*.pem && \
    c_rehash "${__BUILD_DIR__}/etc/ssl/certs" && \
    cat "${__SOURCE_DIR__}/certificates/certs"/*.pem > "${__BUILD_DIR__}/etc/ssl/certs/ca-certificates.crt" && \
    install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/licenses/mozilla/certificates" && \
    curl --silent --location --retry 3 "https://raw.githubusercontent.com/spdx/license-list-data/master/text/MPL-2.0.txt" \
      --output "${__BUILD_DIR__}/licenses/mozilla/certificates/MPL-2.0" && \
    cd ~- && \
    rm -rf "${__SOURCE_DIR__}/certificates" ; \
  } && \
# stripping
  echo '=== stripping binaries ===' && \
  time { \
    find "${__BUILD_DIR__}/usr/bin" "${__BUILD_DIR__}/usr/sbin" -type f -not -links +1 -exec strip --strip-all {} ';' ; \
  } && \
# cleanup
  echo '=== cleaning up ===' && \
  time { \
    rm -rf "${__BUILD_DIR__}/usr/lib" "${__BUILD_DIR__}/usr/include" ; \
  } && \
# licenses
  echo '=== project licenses ===' && \
  time { \
    install --owner="${__USER__}" --group="${__USER__}" --mode=0644 --target-directory="${__BUILD_DIR__}/licenses" "${__WORK_DIR__}/LICENSE" ; \
  } && \
# system settings
  echo '=== system settings ===' && \
  time { \
    install --directory --owner="${__USER__}" --group="${__USER__}" --mode=0755 "${__BUILD_DIR__}/run/systemd" && \
    echo 'docker' > "${__BUILD_DIR__}/run/systemd/container" ; \
  } && \
# done
  echo '=== all done! ==='



FROM scratch

ARG __BUILD_DIR__
ARG __DATA_DIR__
ARG __EASYRSA_DATA_DIR__
ARG __OPENVPN_DATA_DIR__

LABEL \
  maintainer="Frederico Martins <https://hub.docker.com/u/fscm/>" \
  vendor="fscm" \
  cmd="docker container run --interactive --rm --tty --publish 1194:1194/udp --cap-add=NET_ADMIN --device=/dev/net/tun fscm/openvpn start" \
  params="--volume ./:${__DATA_DIR__}:rw"

EXPOSE \
  1194/tcp \
  1194/udp

COPY --from=build "${__BUILD_DIR__}" "/"

VOLUME ["${__DATA_DIR__}"]

WORKDIR "${__DATA_DIR__}"

ENV \
  EASYRSA_DATA_DIR="${__EASYRSA_DATA_DIR__}" \
  OPENVPN_DATA_DIR="${__OPENVPN_DATA_DIR__}"

ENTRYPOINT ["/usr/bin/entrypoint"]

CMD ["help"]
