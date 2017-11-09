#!/bin/sh
## EMQ docker image start script
# Huang Rui <vowstar@gmail.com>

## EMQ Base settings
# Base settings in /opt/emqttd/etc/emq.conf

if [[ ! -z "$DEBUG" ]]; then
    set -ex
fi
LOCAL_IP=$(hostname -i |grep -E -oh '((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])'|head -n 1)

_EMQ_HOME="/opt/emqtt"

if [[ -z "$PLATFORM_ETC_DIR" ]]; then
    export PLATFORM_ETC_DIR="$_EMQ_HOME/etc"
fi

if [[ -z "$PLATFORM_LOG_DIR" ]]; then
    export PLATFORM_LOG_DIR="$_EMQ_HOME/log"
fi

if [[ -z "$EMQ_NAME" ]]; then
    export EMQ_NAME="$(hostname)"
fi

if [[ -z "$EMQ_HOST" ]]; then
    export EMQ_HOST="$LOCAL_IP"
fi

if [[ -z "$EMQ_NODE__NAME" ]]; then
    export EMQ_NODE__NAME="$EMQ_NAME@$EMQ_HOST"
fi

if [[ ! -z "$LOCAL_IP" && ! -z "$EMQ_HOST" ]]; then
    echo "$LOCAL_IP        $EMQ_HOST" >> /etc/hosts
fi

# unset EMQ_NAME
# unset EMQ_HOST

if [[ -z "$EMQ_NODE__PROCESS_LIMIT" ]]; then
    export EMQ_NODE__PROCESS_LIMIT=2097152
fi

if [[ -z "$EMQ_NODE__MAX_PORTS" ]]; then
    export EMQ_NODE__MAX_PORTS=1048576
fi

if [[ -z "$EMQ_NODE__MAX_ETS_TABLES" ]]; then
    export EMQ_NODE__MAX_ETS_TABLES=2097152
fi

if [[ -z "$EMQ_LOG__CONSOLE" ]]; then
    export EMQ_LOG__CONSOLE="console"
fi

if [[ -z "$EMQ_LISTENER__TCP__EXTERNAL__ACCEPTORS" ]]; then
    export EMQ_LISTENER__TCP__EXTERNAL__ACCEPTORS=64
fi

if [[ -z "$EMQ_LISTENER__TCP__EXTERNAL__MAX_CLIENTS" ]]; then
    export EMQ_LISTENER__TCP__EXTERNAL__MAX_CLIENTS=1000000
fi

if [[ -z "$EMQ_LISTENER__SSL__EXTERNAL__ACCEPTORS" ]]; then
    export EMQ_LISTENER__SSL__EXTERNAL__ACCEPTORS=32
fi

if [[ -z "$EMQ_LISTENER__SSL__EXTERNAL__MAX_CLIENTS" ]]; then
    export EMQ_LISTENER__SSL__EXTERNAL__MAX_CLIENTS=500000
fi

if [[ -z "$EMQ_LISTENER__WS__EXTERNAL__ACCEPTORS" ]]; then
    export EMQ_LISTENER__WS__EXTERNAL__ACCEPTORS=16
fi

if [[ -z "$EMQ_LISTENER__WS__EXTERNAL__MAX_CLIENTS" ]]; then
    export EMQ_LISTENER__WS__EXTERNAL__MAX_CLIENTS=250000
fi

# Catch all EMQ_ prefix environment variable and match it in configure file
CONFIG=/opt/emqttd/etc/emq.conf
CONFIG_PLUGINS=/opt/emqttd/etc/plugins
## EMQ Plugins setting

## TODO: Add plugins settings

#if [ x"${RMQ_HOST}" = x ]
#then
#RMQ_HOST="10.1.7.21"
#RMQ_USER="realtime"
#RMQ_PASS="realtime"
#RMQ_VHOST="/"
#RMQ_PORT="5672"
echo 'Loaded RMQ Config [HOST: '${RMQ__HOST}' | PORT: '${RMQ__PORT}' | USER: '${RMQ__USER}' | PASS : '${RMQ__PASS}']'

echo "RMQ_HOST=${RMQ__HOST}"
echo "RMQ_USER=${RMQ__USER}"
echo "RMQ_PASS=${RMQ__PASS}"
echo "RMQ_PORT=${RMQ__PORT}"
#echo "RMQ_VHOST=${RMQ_VHOST}"
#fi
sed -i "/username/s/admin/${RMQ__USER}/" /opt/emqttd/etc/plugins/emqttd_plugin_kafka_bridge.conf
sed -i "/password/s/admin/${RMQ__PASS}/" /opt/emqttd/etc/plugins/emqttd_plugin_kafka_bridge.conf
sed -i "/host/s/10.1.7.130/${RMQ__HOST}/" /opt/emqttd/etc/plugins/emqttd_plugin_kafka_bridge.conf
sed -i "/port/s/5672/${RMQ__PORT}/" /opt/emqttd/etc/plugins/emqttd_plugin_kafka_bridge.conf
#sed -i "/virtualhost/s/admin/${RMQ_VHOST}/" /opt/emqttd/etc/plugins/emqttd_plugin_kafka_bridge.config
## EMQ Main script
# Start and run emqttd, and when emqttd crashed, this container will stop
for VAR in $(env)
do
    # Config normal keys such like node.name = emqttd@127.0.0.1
    if [[ ! -z "$(echo $VAR | grep -E '^EMQ_')" ]]; then
        VAR_NAME=$(echo "$VAR" | sed -r "s/EMQ_(.*)=.*/\1/g" | tr '[:upper:]' '[:lower:]' | sed -r "s/__/\./g")
        VAR_FULL_NAME=$(echo "$VAR" | sed -r "s/(.*)=.*/\1/g")
        # Config in emq.conf
        if [[ ! -z "$(cat $CONFIG |grep -E "^(^|^#*|^#*s*)$VAR_NAME")" ]]; then
            echo "$VAR_NAME=$(eval echo \$$VAR_FULL_NAME)"
            sed -r -i "s/(^#*\s*)($VAR_NAME)\s*=\s*(.*)/\2 = $(eval echo \$$VAR_FULL_NAME)/g" $CONFIG
        fi
        # Config in plugins/*
        if [[ ! -z "$(cat $CONFIG_PLUGINS/* |grep -E "^(^|^#*|^#*s*)$VAR_NAME")" ]]; then
            echo "$VAR_NAME=$(eval echo \$$VAR_FULL_NAME)"
            sed -r -i "s/(^#*\s*)($VAR_NAME)\s*=\s*(.*)/\2 = $(eval echo \$$VAR_FULL_NAME)/g" $(ls $CONFIG_PLUGINS/*)
        fi        
    fi
    # Config template such like {{ platform_etc_dir }}
    if [[ ! -z "$(echo $VAR | grep -E '^PLATFORM_')" ]]; then
        VAR_NAME=$(echo "$VAR" | sed -r "s/(.*)=.*/\1/g"| tr '[:upper:]' '[:lower:]')
        VAR_FULL_NAME=$(echo "$VAR" | sed -r "s/(.*)=.*/\1/g")
        sed -r -i "s@\{\{\s*$VAR_NAME\s*\}\}@$(eval echo \$$VAR_FULL_NAME)@g" $CONFIG
    fi
done


if [[ ! -z "$EMQ_LOADED_PLUGINS" ]]; then
    echo "EMQ_LOADED_PLUGINS=$EMQ_LOADED_PLUGINS"
    # First, remove special char at header
    # Next, replace special char to ".\n" to fit emq loaded_plugins format
    echo $(echo "$EMQ_LOADED_PLUGINS."|sed -e "s/^[^A-Za-z0-9_]\{1,\}//g"|sed -e "s/[^A-Za-z0-9_]\{1,\}/\. /g")|tr ' ' '\n' > /opt/emqttd/data/loaded_plugins
fi


/opt/emqttd/bin/emqttd console
#/opt/emqttd/bin/emqttd console

# wait and ensure emqttd status is running
#WAIT_TIME=0
#while [ x$(/opt/emqttd/bin/emqttd_ctl status |grep 'is running'|awk '{print $1}') = x ]
#do
#    sleep 1
#    echo '['$(date -u +"%Y-%m-%dT%H:%M:%SZ")']:waiting emqttd'
#    WAIT_TIME=`expr ${WAIT_TIME} + 1`
#    if [ ${WAIT_TIME} -gt 5 ]
#    then
#        echo '['$(date -u +"%Y-%m-%dT%H:%M:%SZ")']:timeout error'
#        exit 1
#    fi
#done


echo "['$(date -u +"%Y-%m-%dT%H:%M:%SZ")']:emqttd start"

# Run cluster script

#if [[ -x "./cluster.sh" ]]; then
 #   ./cluster.sh &
#fi

# Join an exist cluster

#if [[ ! -z "$EMQ_JOIN_CLUSTER" ]]; then
#    echo "['$(date -u +"%Y-%m-%dT%H:%M:%SZ")']:emqttd try join $EMQ_JOIN_CLUSTER"
#    /opt/emqttd/bin/emqttd_ctl cluster join $EMQ_JOIN_CLUSTER &
#fi
# monitor emqttd is running, or the docker must stop to let docker PaaS know
# warning: never use infinite loops such as `` while true; do sleep 1000; done`` here
#          you must let user know emqtt crashed and stop this container,
#          and docker dispatching system can known and restart this container.
sleep 10
#/opt/emqttd/bin/emqttd_ctl plugins load emqttd_plugin_kafka_bridge
#echo '['$(date -u +"%Y-%m-%dT%H:%M:%SZ")']:emqttd loaded plugin for RabbitMQ Bridge'

#IDLE_TIME=0
#while [ x$(/opt/emqttd/bin/emqttd_ctl status |grep 'is running'|awk '{print $1}') != x ]
#do
#    IDLE_TIME=`expr ${IDLE_TIME} + 1`
#    echo '['$(date -u +"%Y-%m-%dT%H:%M:%SZ")']:emqttd running'
#    sleep 20
#done


#tail $(ls /opt/emqttd/log/*)

echo '['$(date -u +"%Y-%m-%dT%H:%M:%SZ")']:emqttd stop'
