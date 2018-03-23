#!/bin/bash 
IMAGE=jhsong/sysbio
CONTAINER=hellosysbio
PORT_MAPS="--publish=19921:9995" 
# PORT_MAPS=-P
VOLUME_MAPS="--volume=`pwd`/share:/root/share" 
build() { 
    docker build . -t $IMAGE
}
shell() { 
    docker exec -it ${CONTAINER} bash 
}
start() {
    docker run -it -d --rm --name ${CONTAINER} ${PORT_MAPS} ${VOLUME_MAPS} $IMAGE
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
    update)
        stop & 
        echo "wait stoping ..."
        wait 
        build
        start $2
        ;; 
    start) 
        start
        ;;
    stop) 
        stop
        ;;
    *)
esac
