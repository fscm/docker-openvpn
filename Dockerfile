FROM fscm/debian:stretch as build

ARG BUSYBOX_VERSION="1.27.1-i686"
ARG EASYRSA_VERSION="3.0.1"
ARG EASYRSA_REQ_CITY="Lisboa"
ARG EASYRSA_REQ_COUNTRY="PT"
ARG EASYRSA_REQ_EMAIL="private"
ARG EASYRSA_REQ_ORG="Private Company"
ARG EASYRSA_REQ_OU="IT"
ARG EASYRSA_REQ_PROVINCE="Lisboa"

ENV DEBIAN_FRONTEND=noninteractive

COPY files/* /usr/local/bin/

RUN \
  apt-get -qq update && \
  apt-get -qq -y -o=Dpkg::Use-Pty=0 --no-install-recommends install curl tar openvpn openssl net-tools && \
  apt-get -qq -y -o=Dpkg::Use-Pty=0 download bash openvpn openssl net-tools && \
  sed -i '/path-include/d' /etc/dpkg/dpkg.cfg.d/90docker-excludes && \
  mkdir -p /build/bin && \
  mkdir -p /build/etc/openvpn && \
  mkdir -p /build/data/openvpn && \
  mkdir -p /build/data/easyrsa && \
  mkdir -p /build/opt/easyrsa && \
  dpkg --unpack --force-all --no-triggers --instdir=/build --path-exclude="/etc*" --path-exclude="/lib*" --path-exclude="/usr/*" --path-include="/usr/lib*" --path-include="/usr/sbin*" openvpn_*.deb && \
  dpkg --unpack --force-all --no-triggers --instdir=/build --path-exclude="/etc*" --path-exclude="/usr/*" --path-include="/usr/bin*" openssl_*.deb && \
  dpkg --unpack --force-all --no-triggers --instdir=/build --path-exclude="/usr/*" --path-include="/usr/sbin*" net-tools_*.deb && \
  dpkg --unpack --force-all --no-triggers --instdir=/build --path-exclude="/etc*" --path-exclude="/usr/share*" bash_*.deb && \
  ln -s /bin/bash /build/bin/sh && \
  curl -sL --retry 3 --insecure "https://github.com/OpenVPN/easy-rsa/releases/download/${EASYRSA_VERSION}/EasyRSA-${EASYRSA_VERSION}.tgz" | tar xz --no-same-owner --strip-components=1 -C /build/opt/easyrsa/ && \
  mv /build/opt/easyrsa/vars.example /build/opt/easyrsa/vars && \
  sed -i -r -e 's/#set_var EASYRSA\t/set_var EASYRSA\t/;/^set_var EASYRSA\t/s|\t.*|\t"/data/easyrsa"|' /build/opt/easyrsa/vars && \
  sed -i -r -e '/openssl.exe/s/^/#/;s/#set_var EASYRSA_OPENSSL/set_var EASYRSA_OPENSSL/' /build/opt/easyrsa/vars && \
  sed -i -r -e 's/#set_var EASYRSA_PKI/set_var EASYRSA_PKI/' /build/opt/easyrsa/vars && \
  sed -i -r -e "s/#set_var EASYRSA_REQ_COUNTRY/set_var EASYRSA_REQ_COUNTRY/;/^set_var EASYRSA_REQ_COUNTRY/s|\t.*|\t\"${EASYRSA_REQ_COUNTRY}\"|" /build/opt/easyrsa/vars && \
  sed -i -r -e "s/#set_var EASYRSA_REQ_PROVINCE/set_var EASYRSA_REQ_PROVINCE/;/^set_var EASYRSA_REQ_PROVINCE/s|\t.*|\t\"${EASYRSA_REQ_PROVINCE}\"|" /build/opt/easyrsa/vars && \
  sed -i -r -e "s/#set_var EASYRSA_REQ_CITY/set_var EASYRSA_REQ_CITY/;/^set_var EASYRSA_REQ_CITY/s|\t.*|\t\"${EASYRSA_REQ_CITY}\"|" /build/opt/easyrsa/vars && \
  sed -i -r -e "s/#set_var EASYRSA_REQ_ORG/set_var EASYRSA_REQ_ORG/;/^set_var EASYRSA_REQ_ORG/s|\t.*|\t\"${EASYRSA_REQ_ORG}\"|" /build/opt/easyrsa/vars && \
  sed -i -r -e "s/#set_var EASYRSA_REQ_EMAIL/set_var EASYRSA_REQ_EMAIL/;/^set_var EASYRSA_REQ_EMAIL/s|\t.*|\t\"${EASYRSA_REQ_EMAIL}\"|" /build/opt/easyrsa/vars && \
  sed -i -r -e "s/#set_var EASYRSA_REQ_OU/set_var EASYRSA_REQ_OU/;/^set_var EASYRSA_REQ_OU/s|\t.*|\t\"${EASYRSA_REQ_OU}\"|" /build/opt/easyrsa/vars && \
  sed -i -r -e 's/#set_var EASYRSA_KEY_SIZE/set_var EASYRSA_KEY_SIZE/;/^set_var EASYRSA_KEY_SIZE/s|\t.*|\t2048|' /build/opt/easyrsa/vars && \
  sed -i -r -e 's/#set_var EASYRSA_ALGO/set_var EASYRSA_ALGO/;/^set_var EASYRSA_ALGO/s|\t.*|\trsa|' /build/opt/easyrsa/vars && \
  sed -i -r -e 's/#set_var EASYRSA_CA_EXPIRE/set_var EASYRSA_CA_EXPIRE/;/^set_var EASYRSA_CA_EXPIRE/s|\t.*|\t3650|' /build/opt/easyrsa/vars && \
  sed -i -r -e 's/#set_var EASYRSA_CERT_EXPIRE/set_var EASYRSA_CERT_EXPIRE/;/^set_var EASYRSA_CERT_EXPIRE/s|\t.*|\t3650|' /build/opt/easyrsa/vars && \
  sed -i -r -e 's/#set_var EASYRSA_DIGEST/set_var EASYRSA_DIGEST/;/^set_var EASYRSA_DIGEST/s|\t.*|\t"sha256"|' /build/opt/easyrsa/vars && \
  ln -s /opt/easyrsa/easyrsa /build/usr/bin/easyrsa && \
  mkdir -p /build/run/systemd && \
  echo 'docker' > /build/run/systemd/container && \
  curl -sL --retry 3 --insecure "https://raw.githubusercontent.com/fscm/tools/master/lddcp/lddcp" -o ./lddcp && \
  chmod +x ./lddcp && \
  ./lddcp $(for f in /build/bin/*; do echo "-p ${f} "; done) $(for f in /build/sbin/*; do echo "-p ${f} "; done) $(for f in /build/usr/bin/*; do echo "-p ${f} "; done) $(for f in /build/usr/sbin/*; do echo "-p ${f} "; done) -d /build && \
  curl -sL --retry 3 --insecure "https://busybox.net/downloads/binaries/${BUSYBOX_VERSION}/busybox" -o /build/bin/busybox && \
  chmod +x /build/bin/busybox && \
  for p in [ [[ awk basename cat cp cut date diff du echo env grep ip less ls mkdir mknod mktemp more mv ping printf ps rm sed sort stty tr; do ln -s busybox /build/bin/${p}; done && \
  ln -s /bin/ip /build/sbin/ip && \
  chmod a+x /usr/local/bin/* && \
  cp /usr/local/bin/* /build/bin/



FROM scratch

LABEL \
  maintainer="Frederico Martins <https://hub.docker.com/u/fscm/>"

EXPOSE 1194/udp

COPY --from=build \
  /build .

VOLUME ["/data/openvpn", "/data/easyrsa"]

ENTRYPOINT ["/bin/run"]

CMD ["help"]
