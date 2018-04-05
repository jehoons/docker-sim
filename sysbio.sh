#!/bin/bash 
IMAGE=jhsong/sysbio
CONTAINER=hellosysbio
# PORT_MAPS="--publish=8888:8888" 
PORT_MAPS="-P" 
VOLUME_MAPS="--volume=`pwd`/share:/root/share" 

build() { 
    docker build . -t $IMAGE
}

shell() { 
    docker exec -it ${CONTAINER} bash 
}

start() {
    [ "$1" == "yes" ] && DOCKEROPT="-it --rm" || DOCKEROPT="-it -d --rm"
    docker run ${DOCKEROPT} --name ${CONTAINER} ${PORT_MAPS} ${VOLUME_MAPS} $IMAGE 
}

stop() {
    docker stop --time=10 ${CONTAINER}
}

jup(){
    [ -e "host.txt" ] && hostipaddr=$(cat host.txt) || hostipaddr="localhost"
    jupaddr=$(cat share/logs/jupyterlab.log | grep -o http://0.0.0.0:8888/.*$ | head -1 | sed "s/0.0.0.0/${hostipaddr}/g")
    jupport=$(docker ps | grep --color ${CONTAINER} | grep -o --color "[0-9]\+->8888\+" | sed "s/->8888//g")
    echo 
    echo ${jupaddr} | sed "s/8888/${jupport}/g"
    echo
}

source $(dirname $0)/argparse.bash || exit 1
argparse "$@" <<EOF || exit 1

parser.add_argument('mode', type=str, help='build|start|stop|restart|shell')

parser.add_argument('-f', '--foreground', action='store_true', default=False,
    help='whether foreground mode or not [default %(default)s]')

# parser.add_argument('-m', '--multiple', nargs='+',
#                     help='multiple values allowed')

EOF

case "$MODE" in 
    build) 
        build 
        ;; 
    start) 
        start "$FOREGROUND"
        ;; 
    stop) 
        stop 
        ;; 
    shell) 
        shell  
        ;; 
    restart) 
        stop 
        start "$FOREGROUND"  
        ;; 
    update)
        echo 'stopping ...'
        stop
        echo 'docker build  ...'
        build 
        echo 'starting ...'
        start "$FOREGROUND"  
        ;; 
    jup)
        jup
        ;; 
    *) 
        echo "running with unknown parameter "
esac 

