#!/bin/sh
#
# This script launches nginx and OIDC module.
#
echo "------ version 2024.12.15.01 ------"

handle_term()
{
    echo "received TERM signal"
    echo "stopping nginx ..."
    kill -TERM "${nginx_pid}" 2>/dev/null
}

trap 'handle_term' TERM

# Launch nginx
echo "starting nginx ..."
/usr/sbin/nginx -p /etc/nginx -c /etc/nginx/nginx.conf -g "daemon off; load_module modules/ngx_http_js_module.so;" &

nginx_pid=$!

wait_workers()
{
    while ! pgrep -f 'nginx: worker process' >/dev/null 2>&1; do
        echo "waiting for nginx workers ..."
        sleep 2
    done
}

wait_workers

# Launch nginx-agent
echo "NGINX_AGENT_INSTANCE_GROUP: ${NGINX_AGENT_INSTANCE_GROUP}"
echo "NGINX_AGENT_TAGS: ${NGINX_AGENT_TAGS}"
echo "NGINX_AGENT_SERVER_TOKEN: ${NGINX_AGENT_SERVER_TOKEN}"
echo "NGINX_AGENT_SERVER_HOST: ${NGINX_AGENT_SERVER_HOST}"
echo "NGINX_AGENT_TLS_ENABLE: ${NGINX_AGENT_TLS_ENABLE}"
echo "NGINX_AGENT_SERVER_GRPCPORT: ${NGINX_AGENT_SERVER_GRPCPORT}"
/usr/bin/nginx-agent &

agent_pid=$!

if [ $? != 0 ]; then
    echo "couldn't start the agent, please check nginx-agent logs"
    exit 1
fi

wait_term()
{
    wait ${agent_pid}
    trap '' EXIT INT TERM
    kill -QUIT "${agent_pid}" 2>/dev/null
    echo "waiting for nginx to stop..."
    wait ${nginx_pid}
    trap '' EXIT INT TERM
    kill -QUIT "${nginx_pid}" 2>/dev/null
    echo "waiting for nginx to stop..."
}

wait_term

echo "nginx process has stopped, exiting."
