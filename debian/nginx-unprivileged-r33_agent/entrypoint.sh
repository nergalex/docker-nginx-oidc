#!/bin/sh
#
# This script launches nginx and nginx-agent.
#
echo "------ version 2024.12.18.01 ------"

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
${install_path}/usr/sbin/nginx -p ${install_path}/etc/nginx -c ${install_path}/etc/nginx/nginx.conf -g "daemon off;" &

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
echo "NGINX_AGENT_CONFIG_DIRS: ${NGINX_AGENT_CONFIG_DIRS}"
/usr/bin/nginx-agent &
echo "nginx-agent started"

agent_pid=$!

if [ $? != 0 ]; then
    echo "couldn't start the agent, please check nginx-agent logs"
    exit 1
fi

wait_term()
{
    wait ${nginx_pid}
    trap '' EXIT INT TERM
    echo "nginx stopped"
    echo "stopping nginx-agent ..."
    kill -QUIT "${agent_pid}" 2>/dev/null
    echo "nginx-agent stopped..."
    echo "waiting for NGINX One to set the instance Offline..."
    echo "unregistering nginx-agent..."
    export XC_API_KEY="${XC_API_KEY}"
    export XC_TENANT="${XC_TENANT}"
    sh remove.sh
    echo "nginx-agent unregistered"
}

wait_term
echo "exiting."
