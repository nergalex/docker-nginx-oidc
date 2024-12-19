#!/bin/sh
#
# This script launches nginx and nginx-agent.
#
echo "------ version 2024.12.19.04 ------"

install_path="/nginx"

# move initial file to the empy volume, if empty
mv -f /nginx-initial-config/conf.d ${install_path}/etc/nginx/conf.d
mv -f /nginx-initial-config/modules ${install_path}/etc/nginx/modules
mv -f /nginx-initial-config/uwsgi_params ${install_path}/etc/nginx/uwsgi_params
mv -f /nginx-initial-config/fastcgi_params ${install_path}/etc/nginx/fastcgi_params
mv -f /nginx-initial-config/mime.types ${install_path}/etc/nginx/mime.types
mv -f /nginx-initial-config/nginx.conf ${install_path}/etc/nginx/nginx.conf
mv -f /nginx-initial-config/scgi_params ${install_path}/etc/nginx/scgi_params

handle_term()
{
    echo "`date +%H:%M:%S:%N`: received TERM signal"
    # stopping nginx ...
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
    echo "`date +%H:%M:%S:%N`: nginx stopped"
    # stopping nginx-agent ...
    kill -QUIT "${agent_pid}" 2>/dev/null
    echo "`date +%H:%M:%S:%N`: nginx-agent stopped..."
    # echo "`date +%H:%M:%S:%N`: waiting for NGINX One to set the instance Offline..."
    export XC_API_KEY
    export XC_TENANT
    sh remove.sh
    echo "`date +%H:%M:%S:%N`: nginx-agent unregistered"
}

wait_term
echo "`date`:exiting."
sleep 30
