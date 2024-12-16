ARG RELEASE=bookworm
FROM debian:${RELEASE}-slim as nginx-installer

LABEL maintainer="NGINX Docker Maintainers <docker-maint@nginx.com>"

# Define NGINX versions for NGINX Plus and NGINX Plus modules
# Uncomment this block and the versioned nginxPackages block in the main RUN
# instruction to install a specific release
ARG RELEASE
ARG NGINX_GPGKEY_PATH
ENV NGINX_VERSION=33
ENV NGINX_PKG_RELEASE=2~${RELEASE}
ENV NJS_VERSION=0.8.7
ENV NJS_PKG_RELEASE=1~${RELEASE}
ENV OTEL_VERSION=0.1.0
ENV OTEL_PKG_RELEASE=1~${RELEASE}
ARG TMP_PATH="/nginx-tmp"
ARG CACHE_PATH="/nginx-cache"


# Download your NGINX license certificate and key from the F5 customer portal (https://account.f5.com) and copy to the build context
RUN --mount=type=secret,id=nginx-crt,dst=nginx-repo.crt \
    --mount=type=secret,id=nginx-key,dst=nginx-repo.key \
    set -x \
# Create nginx user/group first, to be consistent throughout Docker variants
    && groupadd --system --gid 101 nginx \
    && useradd --system --gid nginx --no-create-home --home /nonexistent --comment "nginx user" --shell /bin/false --uid 101 nginx \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y ca-certificates gnupg1 lsb-release \
    && \
    NGINX_GPGKEYS="573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62 8540A6F18833A80E9C1653A42FD21310B49F6B46 9E9BE90EACBCDE69FE9B204CBCDCD8A38D88A2B3"; \
    NGINX_GPGKEY_PATH=/usr/share/keyrings/nginx-archive-keyring.gpg; \
    export GNUPGHOME="$(mktemp -d)"; \
    found=''; \
    for NGINX_GPGKEY in $NGINX_GPGKEYS; do \
        for server in \
            hkp://keyserver.ubuntu.com:80 \
            pgp.mit.edu \
        ; do \
            echo "Fetching GPG key $NGINX_GPGKEY from $server"; \
            gpg1 --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$NGINX_GPGKEY" && found=yes && break; \
        done; \
        test -z "$found" && echo >&2 "error: failed to fetch GPG key $NGINX_GPGKEY" && exit 1; \
    done; \
    gpg1 --export "$NGINX_GPGKEYS" > "$NGINX_GPGKEY_PATH" ; \
    rm -rf "$GNUPGHOME"; \
    apt-get remove --purge --auto-remove -y gnupg1 && rm -rf /var/lib/apt/lists/* \
    && nginxPackages=" \
        nginx-plus=${NGINX_VERSION}-${NGINX_PKG_RELEASE} \
        nginx-plus-module-njs=${NGINX_VERSION}+${NJS_VERSION}-${NJS_PKG_RELEASE} \
        nginx-plus-module-otel=${NGINX_VERSION}+${OTEL_VERSION}-${OTEL_PKG_RELEASE} \
    " \
    && echo "Acquire::https::pkgs.nginx.com::Verify-Peer \"true\";" > /etc/apt/apt.conf.d/90nginx \
    && echo "Acquire::https::pkgs.nginx.com::Verify-Host \"true\";" >> /etc/apt/apt.conf.d/90nginx \
    && echo "Acquire::https::pkgs.nginx.com::SslCert     \"/etc/ssl/nginx/nginx-repo.crt\";" >> /etc/apt/apt.conf.d/90nginx \
    && echo "Acquire::https::pkgs.nginx.com::SslKey      \"/etc/ssl/nginx/nginx-repo.key\";" >> /etc/apt/apt.conf.d/90nginx \
    && echo "deb [signed-by=$NGINX_GPGKEY_PATH] https://pkgs.nginx.com/plus/debian `lsb_release -cs` nginx-plus\n" > /etc/apt/sources.list.d/nginx-plus.list \
# NGINX agent
    && echo "deb [signed-by=$NGINX_GPGKEY_PATH] https://pkgs.nginx.com/nginx-agent/debian/ `lsb_release -cs` agent" \
    | tee /etc/apt/sources.list.d/nginx-agent.list \
    && mkdir -p /etc/ssl/nginx \
    && cat nginx-repo.crt > /etc/ssl/nginx/nginx-repo.crt \
    && cat nginx-repo.key > /etc/ssl/nginx/nginx-repo.key \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y \
      $nginxPackages  \
      curl  \
      gettext-base \
      gnupg2 \
      debian-archive-keyring \
      brotli \
      git \
      procps \
# Debug tools for Lab environment only
      vim  \
      binutils  \
      net-tools  \
      jq  \
      tcpdump \
      apt-utils \
      apt-transport-https \
      distro-info-data \
      wget

FROM nginx-installer as oidc-installer
RUN cd /etc/nginx/conf.d \
    && rm -rf * \
    && mkdir -p /nginx-tmp/ \
    && git clone --branch R${NGINX_VERSION} https://github.com/nginxinc/nginx-openid-connect.git /nginx-tmp/ \
    && mv /nginx-tmp/*.conf /etc/nginx/conf.d/ \
    && mv /nginx-tmp/openid_connect.js /etc/nginx/conf.d/ \
    && rm -rf /nginx-tmp

FROM oidc-installer as nginx-agent-installer
ARG NGINX_GPGKEY_PATH
RUN apt install nginx-agent \
    && chown :nginx-agent /var/run/nginx-agent \
    && usermod -a -G nginx-agent nginx

FROM nginx-agent-installer as nginx-config-update
# implement changes required to run NGINX as an unprivileged user
RUN sed -i "s,listen       80;,listen       8080;," /etc/nginx/conf.d/frontend.conf \
    && sed -i "/user  nginx;/d" /etc/nginx/nginx.conf \
    && sed -i "s,.*/var/run/nginx.pid;,pid ${TMP_PATH}/nginx.pid;," /etc/nginx/nginx.conf \
    && sed -i "s,proxy_temp_path.*,proxy_temp_path ${CACHE_PATH}/proxy_temp;," /etc/nginx/nginx.conf \
    && sed -i "s,client_body_temp_path.*,client_body_temp_path ${CACHE_PATH}/client_temp;," /etc/nginx/nginx.conf \
    && sed -i "s,fastcgi_temp_path.*,fastcgi_temp_path ${CACHE_PATH}/fastcgi_temp;," /etc/nginx/nginx.conf \
    && sed -i "s,uwsgi_temp_path.*,uwsgi_temp_path ${CACHE_PATH}/uwsgi_temp;," /etc/nginx/nginx.conf \
    && sed -i "s,scgi_temp_path.*,scgi_temp_path ${CACHE_PATH}/scgi_temp;," /etc/nginx/nginx.conf

FROM nginx-config-update as cleaner
# cleanup sensitive nginx-plus data
RUN apt-get autoremove --purge -y \
      gnupg \
      apt-transport-https \
  && rm -rf /root/.gnupg \
  && rm -rf /var/lib/apt/lists/* \
  && apt-get remove --purge -y lsb-release \
  && apt-get remove --purge --auto-remove -y \
  && rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/nginx-plus.list \
  && rm -rf /etc/apt/apt.conf.d/90nginx /etc/ssl/nginx

FROM cleaner as runner
# Forward request logs to Docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log \
  && ln -sf /dev/stdout /var/log/nginx-agent/agent.log

COPY entrypoint.sh /

EXPOSE 8080
EXPOSE 4443
STOPSIGNAL SIGTERM
ENTRYPOINT ["bash", "/entrypoint.sh"]





