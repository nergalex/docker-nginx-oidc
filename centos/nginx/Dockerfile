#ARG STORE_UUID=False
FROM centos:7 as nginx-installer

LABEL maintainer="F5 SE"

# NGXIN Plus release
ARG NGINX_PLUS_VERSION=28

COPY entrypoint.sh /
COPY remove.sh /

ENV NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62

# Install NGINX Plus
RUN --mount=type=secret,id=nginx-crt,dst=/etc/ssl/nginx/nginx-repo.crt,mode=0644 \
  --mount=type=secret,id=nginx-key,dst=/etc/ssl/nginx/nginx-repo.key,mode=0644 \
  set -ex \
  && yum -y update && yum -y upgrade \
  && yum -y install epel-release \
  && yum -y install wget ca-certificates epel-release curl sudo vim procps gnupg binutils net-tools jq tcpdump git \
  && \
  found=''; \
  for server in \
    ha.pool.sks-keyservers.net \
    hkp://keyserver.ubuntu.com:80 \
    hkp://p80.pool.sks-keyservers.net:80 \
    pgp.mit.edu \
  ; do \
    echo "Fetching GPG key $NGINX_GPGKEY from $server"; \
    gpg --keyserver "$server" --recv-keys "0x$NGINX_GPGKEY" && found=yes && break; \
  done; \
  test -z "$found" && echo >&2 "error: failed to fetch GPG key $NGINX_GPGKEY" && exit 1; \
  wget -P /etc/yum.repos.d https://cs.nginx.com/static/files/nginx-plus-7.4.repo \
  # NGINX Javascript module needed for APIM
  && yum update && yum -y install nginx-plus-${NGINX_PLUS_VERSION}* nginx-plus-module-njs-${NGINX_PLUS_VERSION}*

FROM nginx-installer as oidc-installer
# install OIDC
RUN git clone --branch R${NGINX_PLUS_VERSION} https://github.com/nginxinc/nginx-openid-connect.git /etc/nginx/conf.d

FROM oidc-installer as cleaner
# cleanup sensitive nginx-plus data
RUN gpg --list-keys
RUN rm /etc/yum.repos.d/nginx-plus-7.4.repo \
  && gpg --batch --delete-keys $NGINX_GPGKEY

FROM cleaner as runner

# Forward request logs to Docker log collector
RUN ln -sf /proc/1/fd/2 /var/log/nginx/access.log \
  && ln -sf /proc/1/fd/2 /var/log/nginx/error.log

EXPOSE 80
EXPOSE 443

STOPSIGNAL SIGTERM

ENTRYPOINT ["sh", "/entrypoint.sh"]
