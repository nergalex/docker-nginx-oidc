ARG RELEASE=bookworm
FROM debian:${RELEASE}-slim as nginx-installer

LABEL maintainer="F5 SE"

# Define NGINX versions for NGINX Plus and NGINX Plus modules
ARG NGINX_VERSION=33
ARG NGINX_VERSION_MINOR=2
ARG NJS_VERSION="0.8.7"
ARG INSTALL_PATH="/nginx"
ARG TMP_PATH="/nginx-tmp"
ARG CACHE_PATH="/nginx-cache"

# Download certificate and key from the customer portal (https://account.f5.com)
# and copy to the build context
RUN --mount=type=secret,id=nginx-crt,dst=nginx-repo.crt \
    --mount=type=secret,id=nginx-key,dst=nginx-repo.key \
    --mount=type=secret,id=nginx-lic,dst=license.jwt \
    set -x \
    \
# create nginx user/group first, to be consistent throughout docker variants
    && addgroup --system nginx || true \
    && adduser --system --disabled-login --ingroup nginx --no-create-home --home /nonexistent --gecos "nginx user" --shell /bin/false nginx || true \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y \
                        ca-certificates \
                        gnupg1 \
                        lsb-release \
                        curl \
                        sudo \
                        vim  \
                        procps  \
                        gnupg  \
                        binutils  \
                        net-tools  \
                        jq  \
                        tcpdump \
                        apt-utils \
                        apt-transport-https \
                        distro-info-data \
                        gettext-base \
                        brotli \
                        wget \
                        git \
                        libxml2 \
                        gettext-base \
                        gnupg2 \
                        debian-archive-keyring \
                        dnsutils \
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
# Install the latest release of NGINX Plus and/or NGINX Plus modules
    && echo "Acquire::https::pkgs.nginx.com::Verify-Peer \"true\";" > /etc/apt/apt.conf.d/90nginx \
    && echo "Acquire::https::pkgs.nginx.com::Verify-Host \"true\";" >> /etc/apt/apt.conf.d/90nginx \
    && echo "Acquire::https::pkgs.nginx.com::SslCert     \"/etc/ssl/nginx/nginx-repo.crt\";" >> /etc/apt/apt.conf.d/90nginx \
    && echo "Acquire::https::pkgs.nginx.com::SslKey      \"/etc/ssl/nginx/nginx-repo.key\";" >> /etc/apt/apt.conf.d/90nginx \
    && echo "deb [signed-by=$NGINX_GPGKEY_PATH] https://pkgs.nginx.com/plus/debian `lsb_release -cs` nginx-plus\n" > /etc/apt/sources.list.d/nginx-plus.list \
    && echo "deb [signed-by=$NGINX_GPGKEY_PATH] https://pkgs.nginx.com/nginx-agent/debian/ `lsb_release -cs` agent" \
    | tee /etc/apt/sources.list.d/nginx-agent.list \
    && mkdir -p /etc/ssl/nginx \
    && cat nginx-repo.crt > /etc/ssl/nginx/nginx-repo.crt \
    && cat nginx-repo.key > /etc/ssl/nginx/nginx-repo.key \
    && apt-get update \
    \
# Temporary directory to store installation files
    && tempDir="$(mktemp -d)" \
    && chmod 777 "${tempDir}" \
    && cd ${tempDir} \
    && wget https://raw.githubusercontent.com/nginxinc/nginx-plus-install-tools/main/ngxunprivinst.sh \
    && chmod +x ngxunprivinst.sh \
    \
# Download and Install packages
    && ./ngxunprivinst.sh fetch -c /etc/ssl/nginx/nginx-repo.crt -k /etc/ssl/nginx/nginx-repo.key -v ${NGINX_VERSION}-${NGINX_VERSION_MINOR} \
    && mv nginx-plus_${NGINX_VERSION}* nginx-plus.rpm \
    && mv nginx-plus-module-brotli_${NGINX_VERSION}* nginx-plus-module-brotli.rpm \
    && mv nginx-plus-module-njs_${NGINX_VERSION}%2B${NJS_VERSION}-* nginx-plus-module-njs.rpm \
    && mv nginx-plus-module-subs-filter_${NGINX_VERSION}* nginx-plus-module-subs-filter.rpm \
    && mkdir -p $INSTALL_PATH \
    && cat license.jwt > /license.jwt \
    && ./ngxunprivinst.sh install -y -j /license.jwt -p $INSTALL_PATH nginx-plus.rpm nginx-plus-module-brotli.rpm nginx-plus-module-njs.rpm nginx-plus-module-subs-filter.rpm

FROM nginx-installer as nginx-agent-installer
# Install nginx-agent
RUN apt install nginx-agent \
    && usermod -a -G nginx-agent nginx \
    && chown -R nginx:nginx-agent ${INSTALL_PATH} \
    && chmod -R go+rw ${INSTALL_PATH} \
    && chown -R nginx:nginx-agent /etc/nginx-agent/ \
    && chmod -R go+rw /etc/nginx-agent/ \
    && chown -R nginx:nginx-agent /var/run/nginx-agent  \
    && chmod -R go+rw /var/run/nginx-agent \
    && chown -R nginx:nginx-agent /var/lib/nginx-agent/ \
    && chmod -R go+rw /var/lib/nginx-agent/ \
    && mkdir /var/log/nginx \
    && touch /var/log/nginx/error.log \
    && chown -R nginx:nginx-agent /var/log/nginx \
    && chmod -R go+rw /var/log/nginx \
    && mkdir ${INSTALL_PATH}/var/log/nginx-agent/ \
    && touch ${INSTALL_PATH}/var/log/nginx-agent/agent.log \
    && chown -R nginx:nginx-agent ${INSTALL_PATH}/var/log/nginx-agent \
    && chmod -R g+rw ${INSTALL_PATH}/var/log/nginx-agent

FROM nginx-agent-installer as nginx-initial-config
# implement changes required to run NGINX as an unprivileged user
RUN mkdir -p /nginx-initial-config
COPY nginx.conf /nginx-initial-config/
RUN cp ${INSTALL_PATH}/etc/nginx/uwsgi_params /nginx-initial-config/ \
    && cp ${INSTALL_PATH}/etc/nginx/fastcgi_params /nginx-initial-config/ \
    && cp ${INSTALL_PATH}/etc/nginx/mime.types  /nginx-initial-config/ \
    && cp ${INSTALL_PATH}/etc/nginx/scgi_params /nginx-initial-config/ \
    && chmod -R go+rw /nginx-initial-config/ \
    && chown -R nginx:nginx-agent /nginx-initial-config/

FROM nginx-initial-config as cleaner
# cleanup sensitive nginx-plus data
RUN apt-get autoremove --purge -y \
      gnupg \
      apt-transport-https \
  && rm -rf /root/.gnupg \
  && rm -rf /var/lib/apt/lists/* \
  && rm -rf "${tempDir}" \
  && apt-get remove --purge -y lsb-release \
  && apt-get remove --purge --auto-remove -y && rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/nginx-plus.list \
  && rm -rf /etc/apt/apt.conf.d/90nginx /etc/ssl/nginx \
  && rm -f /license.jwt

FROM cleaner as runner
# Forward request logs to Docker log collector
RUN ln -sf /dev/stdout ${INSTALL_PATH}/var/log/nginx/access.log \
  && ln -sf /dev/stderr ${INSTALL_PATH}/var/log/nginx/error.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log \
  && ln -sf /dev/stdout ${INSTALL_PATH}/var/log/nginx-agent/agent.log

COPY entrypoint.sh /

# NGINX OIDC GW
EXPOSE 8000
EXPOSE 4443
# NGINX JWT VALIDATION GW
EXPOSE 8001
EXPOSE 5443
# NGINX API
EXPOSE 8080
# HEALTHCHECK
EXPOSE 8081
# NGINX-agent API
EXPOSE 8032
# NGINX sync zones
EXPOSE 9000
STOPSIGNAL SIGTERM
USER nginx
ENTRYPOINT ["bash", "/entrypoint.sh"]
