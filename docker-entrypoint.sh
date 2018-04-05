#!/bin/bash -eu
cmd="$1"
if [ "${cmd}" == "startup" ]; then
    mkdir logs
    echo "###########################"
    echo "#      Jupyter lab"
    echo "###########################"
    export SHELL=/bin/bash
    mkdir -p share/logs
    logfile=share/logs/jupyterlab.log
    jupyter lab --port=8888 --no-browser --ip=0.0.0.0 --allow-root --notebook-dir=`pwd` >& ${logfile} & 
    sleep 1
    tail -f ${logfile}
else
    exec "$@"
fi
