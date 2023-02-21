FROM centos:7 as nginx-installer

LABEL maintainer="F5 SE"

# NGXIN Plus release
ARG NGINX_PLUS_VERSION=28
ARG NGINX_PLUS_VERSION_MINOR=1
ARG INSTALL_PATH="/nginx"
ARG TMP_PATH="/nginx-tmp"

COPY entrypoint.sh /

ENV NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62

# Install NGINX Plus
RUN --mount=type=secret,id=nginx-crt,dst=/etc/ssl/nginx/nginx-repo.crt,mode=0644 \
  --mount=type=secret,id=nginx-key,dst=/etc/ssl/nginx/nginx-repo.key,mode=0644 \
  set -ex \
  \
  # create nginx user/group first, to be consistent throughout docker variants
  && addgroup --system nginx || true \
  && adduser --system --disabled-login --ingroup nginx --no-create-home --home /nonexistent --gecos "nginx user" --shell /bin/false nginx || true \
  \
  # Install prerequisites
  && yum -y update && yum -y upgrade \
  && yum -y install epel-release ca-certificates wget curl vim procps gnupg binutils net-tools jq tcpdump git brotli libxslt \
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
  && yum update \
  \
  # Temporary directory to store installation files
  && tempDir="$(mktemp -d)" \
  && chmod 777 "${tempDir}" \
  && cd ${tempDir} \
  && wget https://raw.githubusercontent.com/nginxinc/nginx-plus-install-tools/main/ngxunprivinst.sh \
  && chmod +x ngxunprivinst.sh \
  \
  # Download and Install packages
  && ./ngxunprivinst.sh fetch -c /etc/ssl/nginx/nginx-repo.crt -k /etc/ssl/nginx/nginx-repo.key -v ${NGINX_PLUS_VERSION}-${NGINX_PLUS_VERSION_MINOR} \
  && mv nginx-plus-${NGINX_PLUS_VERSION}-* nginx-plus.rpm \
  && mv nginx-plus-module-brotli-${NGINX_PLUS_VERSION}-* nginx-plus-module-brotli.rpm \
  && mv nginx-plus-module-njs-${NGINX_PLUS_VERSION}-* nginx-plus-module-njs.rpm \
  && mv nginx-plus-module-subs-filter-${NGINX_PLUS_VERSION}-* nginx-plus-module-subs-filter.rpm \
  && mkdir -p $INSTALL_PATH \
  && ./ngxunprivinst.sh install -y -p $INSTALL_PATH nginx-plus.rpm nginx-plus-module-brotli.rpm nginx-plus-module-njs.rpm nginx-plus-module-subs-filter.rpm \
  && chown -R nginx:nginx $INSTALL_PATH \
  && chmod -R g+w $INSTALL_PATH/etc/nginx
  # && rm -rf "${tempDir}"

FROM nginx-installer as oidc-installer
# install OIDC
RUN cd /nginx/etc/nginx/conf.d \
    && rm -rf * \
    && git clone --branch R${NGINX_PLUS_VERSION} https://github.com/nginxinc/nginx-openid-connect.git ${INSTALL_PATH}/etc/nginx/conf.d/

FROM oidc-installer as nginx-config-update
# implement changes required to run NGINX as an unprivileged user
RUN sed -i 's,listen       80;,listen       8080;,' ${INSTALL_PATH}/etc/nginx/conf.d/frontend.conf \
    && sed -i '/user  nginx;/d' ${INSTALL_PATH}/etc/nginx/nginx.conf \
    && sed -i 's,/var/run/nginx.pid,${TMP_PATH}/nginx.pid,' ${INSTALL_PATH}/etc/nginx/nginx.conf \
    && sed -i "/^http {/a \    proxy_temp_path ${TMP_PATH}/proxy_temp;\n    client_body_temp_path ${TMP_PATH}/client_temp;\n    fastcgi_temp_path ${TMP_PATH}/fastcgi_temp;\n    uwsgi_temp_path ${TMP_PATH}/uwsgi_temp;\n    scgi_temp_path ${TMP_PATH}/scgi_temp;\n" ${INSTALL_PATH}/etc/nginx/nginx.conf \

FROM nginx-config-update as cleaner
# cleanup sensitive nginx-plus data
RUN gpg --list-keys
RUN rm /etc/yum.repos.d/nginx-plus-7.4.repo \
  && gpg --batch --delete-keys $NGINX_GPGKEY

FROM cleaner as runner
# Forward request logs to Docker log collector
RUN ln -sf /proc/1/fd/2 /var/log/nginx/access.log \
  && ln -sf /proc/1/fd/2 /var/log/nginx/error.log

EXPOSE 8080
EXPOSE 4443
STOPSIGNAL SIGTERM
USER nginx
ENTRYPOINT ["sh", "/entrypoint.sh"]
