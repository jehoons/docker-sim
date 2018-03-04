#!/bin/bash
build() { 
    echo "build ... " 
} 
start() {
    echo "start ... " 
}

source $(dirname $0)/argparse.bash || exit 1
argparse "$@" <<EOF || exit 1
parser.add_argument('mode', type=str, help='build|start|stop|restart|shell')
parser.add_argument('-a', '--the-answer', default=42, type=int,
                    help='Pick a number [default %(default)s]')
parser.add_argument('-m', '--multiple', nargs='+',
                    help='multiple values allowed')
EOF

#echo required infile: "$INFILE"
#echo the answer: "$THE_ANSWER"
#echo -n do the thing?
#if [[ $DO_THE_THING ]]; then
#    echo " yes, do it"
#else
#    echo " no, do not do it"
#fi
#echo -n "arg with multiple values: "
#for a in "${MULTIPLE[@]}"; do
#    echo -n "[$a] "
#done
#echo

case "$MODE" in 
    build) 
        build 
        ;; 
    start) 
        start 
        ;; 
    stop) 
        stop 
        ;; 
    restart) 
        restart 
        ;; 
    *) 
        echo "" 
esac 

