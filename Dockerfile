# Image for RoadRunner Simulator
#
# VERSION               0.0.2

FROM        ubuntu
MAINTAINER  Stanley Gu <stanleygu@gmail.com>
RUN         apt-get update -qq

# Installing base level packages
RUN         apt-get install -y -q python-software-properties
RUN         apt-get install -y -q python-dev
RUN         apt-get install -y -q python-pip
RUN         apt-get install -y -q build-essential
RUN         apt-get install -y -q git

# Adding PPAs
RUN         add-apt-repository -y ppa:chris-lea/zeromq
RUN         apt-get update -qq

# Install ZMQ
RUN         apt-get -y -q install libzmq3 libzmq3-dev

# Install ZeroRPC
RUN         apt-get install -y libevent-dev python-pip python-gevent msgpack-python
RUN         pip install zerorpc==0.4.4

# Install libSBML
RUN         apt-get install -y -q libxml2 libxml2-dev libtool cmake swig libbz2-dev subversion
RUN         mkdir -p /tmp/projects/libsbml/build_experimental
RUN         cd /tmp/projects/libsbml && svn co https://svn.code.sf.net/p/sbml/code/branches/libsbml-experimental@20107
RUN         cd /tmp/projects/libsbml/build_experimental && cmake -DCMAKE_INSTALL_PREFIX=/usr/local/libsbml -DENABLE_LAYOUT=OFF -DENABLE_RENDER=OFF -DWITH_PYTHON=ON -DWITH_BZIP2=OFF ../libsbml-experimental
RUN         cd /tmp/projects/libsbml/build_experimental && make -j4 && make install
RUN         echo "/usr/local/libsbml/lib/python2.7/site-packages/libsbml" | tee /usr/local/lib/python2.7/dist-packages/libsbml.pth
RUN         echo '/usr/local/libsbml/lib' | tee /etc/ld.so.conf.d/libsbml.conf
RUN         ldconfig
 
# Install RoadRunner
RUN         apt-get update -qq
RUN         apt-get install -y python-numpy swig llvm-3.4-dev libncurses5-dev
RUN         mkdir -p /tmp/rr/build/thirdparty
RUN         mkdir -p /tmp/rr/build/all
RUN         cd /tmp/rr && git clone https://github.com/sys-bio/roadrunner.git
RUN         cd /tmp/rr/roadrunner && git checkout tags/v1.2.2
RUN         cd /tmp/rr/build/thirdparty && cmake ../../roadrunner/third_party/ -DCMAKE_INSTALL_PREFIX=/usr/local/roadrunner/thirdparty
RUN         cd /tmp/rr/build/thirdparty && make -j4 && make install
RUN         cd /tmp/rr/build/all && cmake -DBUILD_PYTHON=ON -DBUILD_LLVM=ON -DBUILD_TESTS=ON -DCMAKE_INSTALL_PREFIX=/usr/local/roadrunner -DTHIRD_PARTY_INSTALL_FOLDER=/usr/local/roadrunner/thirdparty -DLLVM_CONFIG_EXECUTABLE=/usr/bin/llvm-config-3.4 -DBUILD_TEST_TOOLS=ON ../../roadrunner
RUN         cd /tmp/rr/build/all && make -j4 && make install
# Adding to python search path
RUN         echo "/usr/local/roadrunner/site-packages" | tee /usr/local/lib/python2.7/dist-packages/rr.pth
RUN         echo "/usr/local/roadrunner/lib" | tee /etc/ld.so.conf.d/roadrunner.conf
RUN         ldconfig

# Install SBML2MATLAB
RUN         mkdir -p /tmp/projects
RUN         cd /tmp/projects && git clone https://github.com/stanley-gu/sbml2matlab.git
RUN         cd /tmp/projects/sbml2matlab && git checkout 5ddd62d02e1cbec84f6b0e3cf4bd3daae41a900c
RUN         mkdir -p /tmp/projects/sbml2matlab/build
RUN         cd /tmp/projects/sbml2matlab/build && cmake .. -DLIBSBML_INCLUDE_DIR=/usr/local/libsbml/include -DCMAKE_INSTALL_PREFIX=/usr/local/sbml2matlab -DWITH_LIBSBML_LIBXML=ON -DLIBSBML_LIBRARY=/usr/local/libsbml/lib/libsbml-static.a -DWITH_PYTHON=ON -DCMAKE_CXX_FLAGS='-fPIC'
RUN         cd /tmp/projects/sbml2matlab/build && make -j4 && make install
RUN         echo '/usr/local/sbml2matlab/lib/python2.7/site-packages' | tee /usr/local/lib/python2.7/dist-packages/sbml2matlab.pth
RUN         echo '/usr/local/sbml2matlab' | tee /etc/ld.so.conf.d/sbml2matlab.conf
RUN         mv /usr/local/sbml2matlab/lib/python/site-packages/__init__.py /usr/local/sbml2matlab/lib/python2.7/site-packages/sbml2matlab
RUN         ldconfig

# Install antimony
RUN         apt-get install -y -q wget
RUN         cd /tmp/projects && svn checkout https://svn.code.sf.net/p/antimony/code@3523 antimony-code
RUN         mkdir -p /tmp/projects/antimony-code/antimony/build
RUN         cd /tmp/projects/antimony-code/antimony/build && cmake .. -DWITH_PYTHON=ON -DLIBSBML_INCLUDE_DIR=/usr/local/libsbml/include -DCMAKE_INSTALL_PREFIX=/usr/local/antimony -DLIBSBML_LIBRARY=/usr/local/libsbml/lib/libsbml.so -DWITH_QTANTIMONY=OFF -DWITH_CELLML=OFF -DWITH_COMP_SBML=OFF
RUN         cd /tmp/projects/antimony-code/antimony/build && make -j4
RUN         cd /tmp/projects/antimony-code/antimony/build && make install
RUN         mv /python2.7 /usr/local/antimony
RUN         echo '/usr/local/antimony/python2.7/site-packages/antimony' | tee /usr/local/lib/python2.7/dist-packages/libantimony.pth
RUN         echo '/usr/local/antimony/lib' | tee /etc/ld.so.conf.d/antimony.conf
RUN         ldconfig

# Install pysces
RUN         apt-get install -y -q gfortran python-scipy
RUN         pip install pysces==0.9.0

# Install IPython
RUN         apt-get update -qq
RUN         apt-get install -y -q python-matplotlib
RUN         pip install ipython==2.1.0 pyzmq==14.1.1 jinja2==2.7.2 tornado==3.2 pygments==1.6

# Install stats packages
RUN         pip install pandas==0.13.1
RUN         pip install patsy==0.2.1
RUN         pip install statsmodels==0.5.0

# Install tellurium
RUN         git clone https://github.com/sys-bio/tellurium.git /usr/local/lib/python2.7/dist-packages/tellurium
RUN         cd /usr/local/lib/python2.7/dist-packages/tellurium && git checkout 943fa4adfc4c7f0e8f58c75fe4bf1c05d4e04bb1

# Install libsedml
RUN         mkdir -p /tmp/projects
RUN         cd /tmp/projects && git clone https://github.com/fbergmann/libSEDML.git libsedml
RUN         cd /tmp/projects/libsedml && git checkout 7c33ef90866e07981021eabcd985b0aa19b513cf
RUN         mkdir -p /tmp/projects/libsedml/build
RUN         cd /tmp/projects/libsedml/build && cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local/libsedml -DLIBSBML_LIBRARY=/usr/local/libsbml/lib/libsbml-static.a -DLIBSBML_INCLUDE_DIR=/usr/local/libsbml/include -DEXTRA_LIBS=xml2 -DWITH_PYTHON=ON
RUN         cd /tmp/projects/libsedml/build && make -j4
RUN         cd /tmp/projects/libsedml/build && make install
RUN         echo '/usr/local/libsedml/lib/python2.7/site-packages/libsedml' | tee /usr/local/lib/python2.7/dist-packages/libsedml.pth
RUN         echo '/usr/local/libsedml/lib' | tee /etc/ld.so.conf.d/libsedml.conf
RUN         ldconfig

# Install sedml2py
RUN         cd /usr/local && git clone https://github.com/sys-bio/sedml2py.git
RUN         cd /usr/local/sedml2py && git checkout 74d86ec0bd2ae8644ea383f60d551eae4e4f0adf
RUN         echo "/usr/local/sedml2py" | tee /usr/local/lib/python2.7/dist-packages/sedml2py.pth

# Install ipython notebook modules
RUN         cd /usr/local && git clone https://github.com/stanleygu/ipython-notebook-modules.git notebooktools
RUN         cd /usr/local/notebooktools && git checkout tags/v0.0.2
RUN         echo '/usr/local/notebooktools' | tee /usr/local/lib/python2.7/dist-packages/notebooktools.pth

# Other packages
RUN         pip install stochpy==1.1.2 networkx==1.8.1

# Clean up
RUN rm -rf /tmp/projects /tmp/rr
