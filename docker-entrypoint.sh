#!/bin/bash -eu
cmd="$1"
if [ "${cmd}" == "startup" ]; then
    mkdir logs
    # jupyter lab
    export SHELL=/bin/bash
    jupyter lab --port=9995 --no-browser --ip=0.0.0.0 --allow-root \
        --notebook-dir=`pwd` >& logs/jupyterlab.log & 
    sleep 1

    tail -f logs/jupyterlab.log
else
    exec "$@"
fi
