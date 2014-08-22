# Image for RoadRunner Simulator
#
# VERSION               0.0.5

FROM        ubuntu:12.04
MAINTAINER  Stanley Gu <stanleygu@gmail.com>

# Installing base level packages
RUN         apt-get update -qq && apt-get install -y -q python-software-properties python-dev python-pip build-essential git

# Adding PPAs
RUN         add-apt-repository -y ppa:chris-lea/zeromq

# Install ZMQ
RUN         apt-get update -qq && apt-get -y -q install libzmq3 libzmq3-dev libevent-dev python-pip python-gevent msgpack-python

# add a user
RUN         useradd -D --shell=/bin/bash && \
            useradd -m user && \
            echo "user:sysbio" | chpasswd && \
            adduser user sudo

RUN         pip install virtualenv virtualenvwrapper && \
            su user -c "source /usr/local/bin/virtualenvwrapper.sh; mkvirtualenv --system-site-packages localpy" && \
            su user -c "source /usr/local/bin/virtualenvwrapper.sh; workon localpy; pip install zerorpc==0.4.4" # Install ZeroRPC

# Install libSBML
RUN         apt-get install -y -q libxml2 libxml2-dev libtool cmake swig libbz2-dev subversion && \
            mkdir -p /tmp/projects/libsbml/build_experimental && \
            cd /tmp/projects/libsbml && svn co https://svn.code.sf.net/p/sbml/code/branches/libsbml-experimental@20107 && \
            cd /tmp/projects/libsbml/build_experimental && cmake -DCMAKE_INSTALL_PREFIX=/usr/local/libsbml -DENABLE_LAYOUT=OFF -DENABLE_RENDER=OFF -DWITH_PYTHON=ON -DWITH_BZIP2=OFF ../libsbml-experimental && \
            cd /tmp/projects/libsbml/build_experimental && make -j4 && make install && \
            echo "/usr/local/libsbml/lib/python2.7/site-packages/libsbml" | tee /home/user/.virtualenvs/localpy/lib/python2.7/site-packages/libsbml.pth && \
            echo '/usr/local/libsbml/lib' | tee /etc/ld.so.conf.d/libsbml.conf && \
            ldconfig

# Install RoadRunner
RUN         apt-get install -y python-numpy swig llvm-3.4-dev libncurses5-dev && \
            mkdir -p /tmp/rr/build/thirdparty && \
            mkdir -p /tmp/rr/build/all && \
            cd /tmp/rr && git clone https://github.com/sys-bio/roadrunner.git && \
            cd /tmp/rr/roadrunner && git checkout tags/v1.2.2 && \
            cd /tmp/rr/build/thirdparty && cmake ../../roadrunner/third_party/ -DCMAKE_INSTALL_PREFIX=/usr/local/roadrunner/thirdparty && \
            cd /tmp/rr/build/thirdparty && make -j4 && make install && \
            cd /tmp/rr/build/all && cmake -DBUILD_PYTHON=ON -DBUILD_LLVM=ON -DBUILD_TESTS=ON -DCMAKE_INSTALL_PREFIX=/usr/local/roadrunner -DTHIRD_PARTY_INSTALL_FOLDER=/usr/local/roadrunner/thirdparty -DLLVM_CONFIG_EXECUTABLE=/usr/bin/llvm-config-3.4 -DBUILD_TEST_TOOLS=ON ../../roadrunner && \
            cd /tmp/rr/build/all && make -j4 && make install && \
# Adding to python search path
            echo "/usr/local/roadrunner/site-packages" | tee /home/user/.virtualenvs/localpy/lib/python2.7/site-packages/rr.pth && \
            echo "/usr/local/roadrunner/lib" | tee /etc/ld.so.conf.d/roadrunner.conf && \
            ldconfig

# Install SBML2MATLAB
RUN         mkdir -p /tmp/projects && \
            cd /tmp/projects && \
            cd /tmp/projects && git clone https://github.com/stanleygu/sbml2matlab.git && \
            cd /tmp/projects/sbml2matlab && git checkout 5e79fd959757ea53e9e548c605e7fd1dbddc7af8 && \
            mkdir -p /tmp/projects/sbml2matlab/build && \
            cd /tmp/projects/sbml2matlab/build && cmake .. -DLIBSBML_INCLUDE_DIR=/usr/local/libsbml/include -DCMAKE_INSTALL_PREFIX=/usr/local/sbml2matlab -DWITH_LIBSBML_LIBXML=ON -DLIBSBML_LIBRARY=/usr/local/libsbml/lib/libsbml-static.a -DWITH_PYTHON=ON -DCMAKE_CXX_FLAGS='-fPIC' && \
            cd /tmp/projects/sbml2matlab/build && make -j4 && make install && \
            echo '/usr/local/sbml2matlab/lib/python2.7/site-packages' | tee /home/user/.virtualenvs/localpy/lib/python2.7/site-packages/sbml2matlab.pth && \
            echo '/usr/local/sbml2matlab' | tee /etc/ld.so.conf.d/sbml2matlab.conf && \
            mv /usr/local/sbml2matlab/lib/python/site-packages/__init__.py /usr/local/sbml2matlab/lib/python2.7/site-packages/sbml2matlab && \
            ldconfig

# Install antimony
RUN         apt-get install -y -q wget && \
            cd /tmp/projects && svn checkout https://svn.code.sf.net/p/antimony/code@3523 antimony-code && \
            mkdir -p /tmp/projects/antimony-code/antimony/build && \
            cd /tmp/projects/antimony-code/antimony/build && cmake .. -DWITH_PYTHON=ON -DLIBSBML_INCLUDE_DIR=/usr/local/libsbml/include -DCMAKE_INSTALL_PREFIX=/usr/local/antimony -DLIBSBML_LIBRARY=/usr/local/libsbml/lib/libsbml.so -DWITH_QTANTIMONY=OFF -DWITH_CELLML=OFF -DWITH_COMP_SBML=OFF && \
            cd /tmp/projects/antimony-code/antimony/build && make -j4 && \
            cd /tmp/projects/antimony-code/antimony/build && make install && \
            mv /python2.7 /usr/local/antimony && \
            echo '/usr/local/antimony/python2.7/site-packages/antimony' | tee /home/user/.virtualenvs/localpy/lib/python2.7/site-packages/libantimony.pth && \
            echo '/usr/local/antimony/lib' | tee /etc/ld.so.conf.d/antimony.conf && \
            ldconfig

# Install pysces
RUN         apt-get install -y -q gfortran python-scipy && \
            su user -c "source /usr/local/bin/virtualenvwrapper.sh; workon localpy; pip install pysces==0.9.0"

# Install IPython
RUN         apt-get install -y -q python-matplotlib && \
            su user -c "source /usr/local/bin/virtualenvwrapper.sh; workon localpy; pip install ipython==2.1.0 jinja2==2.7.2 tornado==3.2 pygments==1.6" && \
            pip install pyzmq==14.1.1

# Install stats packages
RUN         su user -c "source /usr/local/bin/virtualenvwrapper.sh; workon localpy; pip install pandas==0.13.1" && \
            su user -c "source /usr/local/bin/virtualenvwrapper.sh; workon localpy; pip install patsy==0.2.1" && \
            su user -c "source /usr/local/bin/virtualenvwrapper.sh; workon localpy; pip install statsmodels==0.5.0"

# Install libsedml
RUN         mkdir -p /tmp/projects && \
            cd /tmp/projects && git clone https://github.com/fbergmann/libSEDML.git libsedml && \
            cd /tmp/projects/libsedml && git checkout 7c33ef90866e07981021eabcd985b0aa19b513cf && \
            mkdir -p /tmp/projects/libsedml/build && \
            cd /tmp/projects/libsedml/build && cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local/libsedml -DLIBSBML_LIBRARY=/usr/local/libsbml/lib/libsbml-static.a -DLIBSBML_INCLUDE_DIR=/usr/local/libsbml/include -DEXTRA_LIBS=xml2 -DWITH_PYTHON=ON && \
            cd /tmp/projects/libsedml/build && make -j4 && \
            cd /tmp/projects/libsedml/build && make install && \
            echo '/usr/local/libsedml/lib/python2.7/site-packages/libsedml' | tee /home/user/.virtualenvs/localpy/lib/python2.7/site-packages/libsedml.pth && \
            echo '/usr/local/libsedml/lib' | tee /etc/ld.so.conf.d/libsedml.conf && \
            ldconfig

# Install sedml2py
RUN         cd /usr/local && git clone https://github.com/sys-bio/sedml2py.git && \
            cd /usr/local/sedml2py && git checkout 74d86ec0bd2ae8644ea383f60d551eae4e4f0adf && \
            echo "/usr/local/sedml2py" | tee /home/user/.virtualenvs/localpy/lib/python2.7/site-packages/sedml2py.pth

# Install ipython notebook modules
RUN         cd /usr/local && git clone https://github.com/stanleygu/ipython-notebook-tools.git notebooktools && \
            cd /usr/local/notebooktools && git checkout tags/v0.0.3 && \
            echo '/usr/local/notebooktools' | tee /home/user/.virtualenvs/localpy/lib/python2.7/site-packages/notebooktools.pth

# Install tellurium
RUN         git clone https://github.com/sys-bio/tellurium.git /home/user/.virtualenvs/localpy/lib/python2.7/site-packages/tellurium && \
            cd /home/user/.virtualenvs/localpy/lib/python2.7/site-packages/tellurium && git checkout a4b25cdc173128ad2793c83d35043140b74e5a1f


# Other packages
RUN         su user -c "source /usr/local/bin/virtualenvwrapper.sh; workon localpy; pip install stochpy==1.1.2 networkx==1.8.1"

# Clean up
RUN rm -rf /tmp/projects /tmp/rr
