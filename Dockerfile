# Image for RoadRunner Simulation 
#
# VERSION               0.0.1

FROM        ubuntu
MAINTAINER  Stanley Gu <stanleygu@gmail.com>
RUN         apt-get update -qq

# Installing base level packages
RUN         apt-get install -y -q python-software-properties
RUN         apt-get install -y -q python-dev
RUN         apt-get install -y -q python-pip
RUN         apt-get install -y -q git


# Adding PPAs
RUN         add-apt-repository -y ppa:chris-lea/zeromq
RUN         apt-get update -qq

# Install ZMQ
RUN         apt-get -y -q install libzmq3

# Install ZeroRPC
RUN         apt-get install -y libevent-dev python-pip python-gevent msgpack-python
RUN         pip install zerorpc

# Install libSBML
RUN         apt-get install -y -q build-essential libxml2 libxml2-dev python-dev libtool cmake swig libbz2-dev subversion
RUN         mkdir -p /tmp/projects/libsbml/build_experimental
RUN         cd /tmp/projects/libsbml && svn co https://svn.code.sf.net/p/sbml/code/branches/libsbml-experimental
RUN         cd /tmp/projects/libsbml/build_experimental && cmake -DCMAKE_INSTALL_PREFIX=/usr/local/libsbml -DENABLE_LAYOUT=OFF -DENABLE_RENDER=OFF -DWITH_PYTHON=ON -DWITH_BZIP2=OFF ../libsbml-experimental
RUN         cd /tmp/projects/libsbml/build_experimental && make -j4 && make install
RUN         echo "/usr/local/libsbml/lib/python2.7/site-packages/libsbml" | tee /usr/local/lib/python2.7/dist-packages/libsbml.pth
RUN         echo '/usr/local/libsbml/lib' | tee /etc/ld.so.conf.d/libsbml.conf
RUN         ldconfig
 
# Install RoadRunner
RUN         apt-get install -y python-numpy swig llvm-3.2 git
RUN         mkdir -p /tmp/rr/build/thirdparty
RUN         mkdir -p /tmp/rr/build/all
RUN         cd /tmp/rr && git clone https://github.com/AndySomogyi/roadrunner.git
RUN         cd /tmp/rr/build/thirdparty && cmake ../../roadrunner/third_party/ -DCMAKE_INSTALL_PREFIX=/usr/local/roadrunner/thirdparty
RUN         cd /tmp/rr/build/thirdparty && make -j4 && make install
RUN         cd /tmp/rr/build/all && cmake -DBUILD_PYTHON=ON -DBUILD_LLVM=ON -DBUILD_TESTS=ON -DCMAKE_INSTALL_PREFIX=/usr/local/roadrunner -DTHIRD_PARTY_INSTALL_FOLDER=/usr/local/roadrunner/thirdparty -DLLVM_CONFIG_EXECUTABLE=/usr/bin/llvm-config-3.2 -DBUILD_PLUGINS=OFF ../../roadrunner
RUN         cd /tmp/rr/build/all && make -j4 && make install
# Adding to python search path
RUN         echo "/usr/local/roadrunner/site-packages/roadrunner" | tee /usr/local/lib/python2.7/dist-packages/rr.pth
RUN         echo "/usr/local/roadrunner/site-packages/roadrunner/testing" | tee -a /usr/local/lib/python2.7/dist-packages/rr.pth
RUN         echo "/usr/local/roadrunner/lib" | tee /etc/ld.so.conf.d/roadrunner.conf
RUN         ldconfig

# Install SBML2MATLAB
RUN         mkdir -p /tmp/projects
RUN         cd /tmp/projects && git clone https://github.com/stanley-gu/sbml2matlab.git
RUN         mkdir -p /tmp/projects/sbml2matlab/build
RUN         cd /tmp/projects/sbml2matlab/build && cmake .. -DLIBSBML_INCLUDE_DIR=/usr/local/libsbml/include -DCMAKE_INSTALL_PREFIX=/usr/local/sbml2matlab -DWITH_LIBSBML_LIBXML=ON -DLIBSBML_STATIC_LIBRARY=/usr/local/libsbml/lib/libsbml-static.a -DWITH_PYTHON=ON
RUN         cd /tmp/projects/sbml2matlab/build && make -j4 && make install
RUN         echo '/usr/local/sbml2matlab/lib/python2.7/site-packages/sbml2matlab' | tee /usr/local/lib/python2.7/dist-packages/sbml2matlab.pth
RUN         echo '/usr/local/sbml2matlab' | tee /etc/ld.so.conf.d/sbml2matlab.conf
RUN         ldconfig

# Add RPC Server
ADD         server.py /usr/local/sim/server.py

# Clean up
RUN rm -rf /tmp/projects /tmp/rr
