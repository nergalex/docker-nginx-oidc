#!/bin/sh
#
# This script launches nginx and nginx-agent.
#
echo "------ version 2025.01.08.01 ------"

install_path="/nginx"

# copy initial file to the empy volume, in case of being empty
cp -prf /nginx-initial-config/conf.d ${install_path}/etc/nginx/conf.d
cp -pf /nginx-initial-config/uwsgi_params ${install_path}/etc/nginx/uwsgi_params
cp -pf /nginx-initial-config/fastcgi_params ${install_path}/etc/nginx/fastcgi_params
cp -pf /nginx-initial-config/mime.types ${install_path}/etc/nginx/mime.types
cp -pf /nginx-initial-config/nginx.conf ${install_path}/etc/nginx/nginx.conf
cp -pf /nginx-initial-config/scgi_params ${install_path}/etc/nginx/scgi_params

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
