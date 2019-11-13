FROM fscm/debian:buster as build

ARG BUSYBOX_VERSION="1.31.0"
ARG EASYRSA_VERSION="3.0.6"
ARG EASYRSA_REQ_CITY="Lisboa"
ARG EASYRSA_REQ_COUNTRY="PT"
ARG EASYRSA_REQ_EMAIL="private"
ARG EASYRSA_REQ_ORG="Private Company"
ARG EASYRSA_REQ_OU="IT"
ARG EASYRSA_REQ_PROVINCE="Lisboa"
ARG IPTABLES_VERSION="1.8.3"
ARG OPENSSL_VERSION="1.1.1d"
ARG OPENVPN_VERSION="2.4.7"

ENV \
  LANG=C.UTF-8 \
  DEBIAN_FRONTEND=noninteractive

COPY files/ /root/

WORKDIR /root

RUN \
# dependencies
  apt-get -qq update && \
  apt-get -qq -y -o=Dpkg::Use-Pty=0 --no-install-recommends install \
    bison \
    ca-certificates \
    curl \
    dpkg-dev \
    flex \
    gcc \
    libc-dev \
    liblz4-dev \
    liblzo2-dev \
    libmnl-dev \
    libnetfilter-conntrack-dev \
    libpam0g-dev \
    libpcap-dev \
    libpkcs11-helper1-dev \
    libtool \
    make \
    tar \
    > /dev/null 2>&1 && \
# build structure
  for folder in bin sbin lib lib64; do install --directory --owner=root --group=root --mode=0755 /build/usr/${folder}; ln -s usr/${folder} /build/${folder}; done && \
  for folder in tmp data; do install --directory --owner=root --group=root --mode=1777 /build/${folder}; done && \
# copy tests
  #install --directory --owner=root --group=root --mode=0755 /build/usr/bin && \
  install --owner=root --group=root --mode=0755 --target-directory=/build/usr/bin /root/tests/* && \
# copy scripts
  install --owner=root --group=root --mode=0755 --target-directory=/build/usr/bin /root/scripts/* && \
# busybox
  curl --silent --location --retry 3 "https://busybox.net/downloads/binaries/${BUSYBOX_VERSION}-i686-uclibc/busybox" \
    -o /build/usr/bin/busybox && \
  chmod +x /build/usr/bin/busybox && \
  for p in [ awk basename cat chmod cp cut date diff dirname du env getopt grep gzip hostname id ip kill killall less ln ls mkdir mknod mktemp more mv netstat pgrep ping printf ps pwd rm sed sh sort stty sysctl tar tr wget; do ln /build/usr/bin/busybox /build/usr/bin/${p}; done && \
  for p in arp ifconfig ip ipaddr iptunnel nameif route slattach; do ln /build/usr/bin/busybox /build/usr/sbin/${p}; done && \
# use busybox
  for p in arp ifconfig ip ipaddr iptunnel nameif route slattach; do ln -s /build/usr/bin/busybox /usr/sbin/${p}; done && \
# openssl
  install --directory /src/openssl && \
  curl --silent --location --retry 3 "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz" \
    | tar xz --no-same-owner --strip-components=1 -C /src/openssl && \
  cd /src/openssl && \
  ./config -Wl,-rpath=/usr/lib/x86_64-linux-gnu \
    --prefix="/usr" \
    --openssldir="/etc/ssl" \
    --libdir="/usr/lib/$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
    no-idea \
    no-mdc2 \
    no-rc5 \
    no-zlib \
    no-ssl3 \
    no-ssl3-method \
    enable-rfc3779 \
    enable-cms \
    enable-ec_nistp_64_gcc_128 && \
  make --silent -j "$(getconf _NPROCESSORS_ONLN)" && \
  make --silent install_sw install_ssldirs DESTDIR=/build INSTALL='install -p' && \
  find /build -depth -type f -name c_rehash -delete && \
  find /build -depth \( \( -type d -a \( -name include -o -name pkgconfig -o -name share \) \) -o \( -type f -a \( -name '*.a' -o -name '*.la' -o -name '*.dist' \) \) \) -exec rm -rf '{}' + && \
  cd - && \
# use built openssl
  rm -f /usr/lib/x86_64-linux-gnu/libssl.so* /usr/bin/openssl && \
  ln -s /build/usr/lib/x86_64-linux-gnu/libssl.so* /usr/lib/x86_64-linux-gnu/ && \
  ln -s /build/usr/bin/openssl /usr/bin/openssl && \
  #echo '/build/usr/lib/x86_64-linux-gnu' > /etc/ld.so.conf.d/00_build.conf && \
  #ldconfig && \
# iptables
  install --directory /src/iptables && \
  curl --silent --location --retry 3 "https://www.netfilter.org/projects/iptables/files/iptables-${IPTABLES_VERSION}.tar.bz2" \
    | tar xj --no-same-owner --strip-components=1 -C /src/iptables && \
  cd /src/iptables && \
  ./configure LDFLAGS="-Wl,-rpath=/usr/lib/x86_64-linux-gnu" \
    --quiet \
    --prefix="/usr" \
    --libdir="/usr/lib/$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
    --with-xtlibdir="/usr/lib/$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)/xtables" \
    --enable-connlabel \
    --enable-bpf-compiler \
    --enable-nfsynproxy \
    --disable-devel \
    --disable-libipq \
    --disable-nftables \
    --disable-shared && \
  make --silent -j "$(getconf _NPROCESSORS_ONLN)" && \
  make --silent install DESTDIR=/build INSTALL='install -p' && \
  find /build -depth \( \( -type d -a \( -name include -o -name pkgconfig -o -name share \) \) -o \( -type f -a \( -name '*.a' -o -name '*.la' -o -name '*.dist' \) \) \) -exec rm -rf '{}' + && \
  cd - && \
# openvpn
  install --directory /src/openvpn && \
  curl --silent --location --retry 3 "https://swupdate.openvpn.org/community/releases/openvpn-${OPENVPN_VERSION}.tar.gz" \
    | tar xz --no-same-owner --strip-components=1 -C /src/openvpn && \
  cd /src/openvpn && \
  ./configure LDFLAGS="-Wl,-rpath=/usr/lib/x86_64-linux-gnu" \
    --quiet \
    --prefix="/usr" \
    --libdir="/usr/lib/$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
    --with-crypto-library=openssl \
    --enable-iproute2 \
    --enable-pkcs11 \
    --enable-shared \
    --enable-x509-alt-username \
    --disable-debug \
    --disable-static && \
  make --silent -j "$(getconf _NPROCESSORS_ONLN)" && \
  make --silent install DESTDIR=/build INSTALL='install -p' && \
  find /build -depth \( \( -type d -a \( -name include -o -name pkgconfig -o -name share \) \) -o \( -type f -a \( -name '*.a' -o -name '*.la' -o -name '*.dist' \) \) \) -exec rm -rf '{}' + && \
  cd - && \
# easyrsa
  install --directory --owner=root --group=root --mode=0755 /build/usr/local/easyrsa && \
  curl --silent --location --retry 3 "https://github.com/OpenVPN/easy-rsa/releases/download/v${EASYRSA_VERSION}/EasyRSA-unix-v${EASYRSA_VERSION}.tgz" \
    | tar xz --no-same-owner --strip-components=1 -C /build/usr/local/easyrsa/ && \
  find /build/usr/local/easyrsa -depth \( \( -type d -a -name doc \) -o \( -type f -a \( -name '*.txt' -o -name '*.md' -o -name '*ChangeLog*' \) \) \) -exec rm -rf '{}' + && \
  sed \
    -e '/set_var EASYRSA\t/ s|^#\(.*\)".*"|\1"/data/easyrsa"|' \
    -e '/set_var EASYRSA_OPENSSL.*"openssl"$/ s|^#||' \
    -e '/set_var EASYRSA_PKI\t/ s|^#\(.*\)".*"|\1"/data/easyrsa/pki"|' \
    -e '/set_var EASYRSA_PKI/ s|^#||' \
    -e "/set_var EASYRSA_REQ_COUNTRY\t/ s|^#\(.*\)\".*\"|\1\"${EASYRSA_REQ_COUNTRY}\"|" \
    -e "/set_var EASYRSA_REQ_PROVINCE\t/ s|^#\(.*\)\".*\"|\1\"${EASYRSA_REQ_PROVINCE}\"|" \
    -e "/set_var EASYRSA_REQ_CITY\t/ s|^#\(.*\)\".*\"|\1\"${EASYRSA_REQ_CITY}\"|" \
    -e "/set_var EASYRSA_REQ_ORG\t/ s|^#\(.*\)\".*\"|\1\"${EASYRSA_REQ_ORG}\"|" \
    -e "/set_var EASYRSA_REQ_EMAIL\t/ s|^#\(.*\)\".*\"|\1\"${EASYRSA_REQ_EMAIL}\"|" \
    -e "/set_var EASYRSA_REQ_OU\t/ s|^#\(.*\)\".*\"|\1\"${EASYRSA_REQ_OU}\"|" \
    -e '/set_var EASYRSA_KEY_SIZE\t/ s|^#\(.*[[:space:]]\).*|\12048|' \
    -e '/set_var EASYRSA_ALGO\t/ s|^#\(.*[[:space:]]\).*|\1rsa|' \
    -e '/set_var EASYRSA_CA_EXPIRE\t/ s|^#\(.*[[:space:]]\).*|\13650|' \
    -e '/set_var EASYRSA_CERT_EXPIRE\t/ s|^#\(.*[[:space:]]\).*|\13650|' \
    -e "/set_var EASYRSA_DIGEST\t/ s|^#\(.*\)\".*\"|\1\"sha256\"|" \
    /build/usr/local/easyrsa/vars.example \
    > /build/usr/local/easyrsa/vars && \
  ln -s /usr/local/easyrsa/easyrsa /build/usr/bin/easyrsa && \
# system settings
  install --directory --owner=root --group=root --mode=0755 /build/run/systemd && \
  echo 'docker' > /build/run/systemd/container && \
# lddcp
  curl --silent --location --retry 3 "https://raw.githubusercontent.com/fscm/tools/master/lddcp/lddcp" -o ./lddcp && \
  chmod +x ./lddcp && \
  ./lddcp $(for f in `find /build/ -type f -executable`; do echo "-p $f "; done) $(for f in `find /lib/x86_64-linux-gnu/ \( -name 'libnss*' -o -name 'libresolv*' \)`; do echo "-l $f "; done) -d /build && \
# ca certificates
  install --owner=root --group=root --mode=0644 --target-directory=/build/etc/ssl/certs /etc/ssl/certs/*.pem && \
  chroot /build openssl rehash /etc/ssl/certs



FROM scratch

LABEL \
  maintainer="Frederico Martins <https://hub.docker.com/u/fscm/>"

EXPOSE \
  1194 \
  1194/udp

COPY --from=build \
  /build .

VOLUME ["/data"]

WORKDIR /data

ENV LANG=C.UTF-8

ENTRYPOINT ["/usr/bin/run"]

CMD ["help"]
