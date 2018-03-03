#!/bin/bash 
IMAGE=sysbio
CONTAINER=hellosysbio
build() { 
    docker build . -t $IMAGE
}
shell() { 
    docker exec -it ${CONTAINER} bash 
}
start() {
    docker run -d -it --rm --name ${CONTAINER} $IMAGE
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
