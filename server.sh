#!/bin/bash 
IMAGE=jhsong/sysbio
CONTAINER=hellosysbio
PORT_MAPS="--publish=9995:9995" 
VOLUME_MAPS="--volume=`pwd`/share:/root/share" 
build() { 
    docker build . -t $IMAGE
}
shell() { 
    docker exec -it ${CONTAINER} bash 
}
start() {
    [ "$1" == "yes" ] && \
    docker run -it    --rm --name ${CONTAINER} ${PORT_MAPS} ${VOLUME_MAPS} $IMAGE || 
    docker run -it -d --rm --name ${CONTAINER} ${PORT_MAPS} ${VOLUME_MAPS} $IMAGE 
}
stop() {
    docker stop ${CONTAINER}
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
    restart) 
        stop 
        start "$FOREGROUND"  
        ;; 
    *) 
        # echo "" 
esac 

