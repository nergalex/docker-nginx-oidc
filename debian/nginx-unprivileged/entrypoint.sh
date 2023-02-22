#!/bin/sh
#
# This script launches nginx and OIDC module.
#
echo "------ version 2023.02.22.07 ------"

install_path="/nginx"

handle_term()
{
    echo "received TERM signal"
    echo "stopping nginx ..."
    kill -TERM "${nginx_pid}" 2>/dev/null
}

trap 'handle_term' TERM

# Launch nginx
echo "starting nginx ..."
${install_path}/usr/sbin/nginx -p ${install_path}/etc/nginx -c ${install_path}/etc/nginx/nginx.conf -g "daemon off; load_module modules/ngx_http_js_module.so;" &

nginx_pid=$!

wait_workers()
{
    while ! pgrep -f 'nginx: worker process' >/dev/null 2>&1; do
        echo "waiting for nginx workers ..."
        sleep 2
    done
}

wait_workers

wait_term()
{
    wait ${nginx_pid}
    trap '' EXIT INT TERM
    kill -QUIT "${nginx_pid}" 2>/dev/null
    echo "waiting for nginx to stop..."
}
wait_term

echo "nginx process has stopped, exiting."
