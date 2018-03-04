#!/bin/bash 
IMAGE=jhsong/sysbio
CONTAINER=hellosysbio
PORT_MAPS="--publish=9995:9995" 

build() { 
    docker build . -t $IMAGE
}
shell() { 
    docker exec -it ${CONTAINER} bash 
}
start() {
    docker run -it -d --rm --name ${CONTAINER} ${PORT_MAPS} \
        $IMAGE
}
stop() {
    docker stop ${CONTAINER}
}
case "$1" in
    shell)
        shell 
        ;; 
    build)
        build $2
        ;;
    start)
        start $2
        ;;
    stop)
        stop
        ;;
    restart)
        stop & 
        echo "wait stoping ..."
        wait 
        start $2
        ;; 
    start) 
        start
        ;;
    stop) 
        stop
        ;;
    *)
        echo 
        echo "Usage $0 shell"
        echo "Usage $0 build"
        echo "Usage $0 start"
        echo "Usage $0 stop"
        echo "Usage $0 restart"
        echo 
esac
