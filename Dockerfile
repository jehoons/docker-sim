# Image for RoadRunner Simulator
#
# VERSION               20141016

FROM        ubuntu:16.04
MAINTAINER  Stanley Gu <stanleygu@gmail.com>

WORKDIR /root

# Installing base level packages
RUN   apt-get update -qq && apt-get install -y -q python-software-properties \
      python-dev \
      python-pip \
      build-essential \
      git

################
## Install ZMQ
# RUN   apt-get update -qq && apt-get -y -q install libzmq3 libzmq3-dev 
# Install dependency
RUN   apt-get update && apt-get install -y libtool pkg-config build-essential \
      autoconf automake uuid-dev software-properties-common wget 
# RUN   mkdir -p temp && cd temp && git clone https://github.com/zeromq/libzmq 
RUN   mkdir -p tmp && cd tmp && \
      wget https://github.com/zeromq/libzmq/releases/download/v4.2.2/zeromq-4.2.2.tar.gz 
# Unpack tarball package
RUN   cd tmp && tar xvzf zeromq-4.2.2.tar.gz
# Create make file
RUN   cd tmp/zeromq-4.2.2 && ./configure && make install 

# Install zeromq driver on linux
RUN   ldconfig

# RUN apt-get update \
#       && apt-get install -y python3-pip python3-dev \
#       && cd /usr/local/bin \
#       && ln -s /usr/bin/python3 python \
#       && pip3 install --upgrade pip
ENV PYTHON_VER=python2.7

RUN   apt-get update && apt-get -y install libevent-dev python-gevent msgpack-python libtool-bin

# # add a user
# RUN   apt-get update -qq
# RUN   useradd --shell=/bin/bash --create-home --home-dir=/home/user user && \
#       echo "user:sysbio" | chpasswd && \
#       adduser user sudo

RUN   apt-get install -y vim

#################
# Install libSBML
ENV   libSBML_5=libSBML-5.15.2-Source

RUN   apt-get install -y -q libxml2 libxml2-dev libtool cmake swig libbz2-dev subversion

RUN   mkdir -p tmp/libsbml && cd tmp/libsbml && \
      wget https://ndownloader.figshare.com/files/10639657 -O ${libSBML_5}.tar.gz && \
      tar xvfz ${libSBML_5}.tar.gz && cd ${libSBML_5}

RUN   cd tmp/libsbml/${libSBML_5} && ./configure --prefix=/usr/local/libsbml \
           --enable-layout=no --enable-render=no --with-python=yes --with-bzip2=no

RUN   cd tmp/libsbml/${libSBML_5} && make -j60

RUN   mkdir -p /usr/local/libsbml/lib/${PYTHON_VER}/site-packages/

ENV   PYTHONPATH=/usr/local/libsbml/lib/${PYTHON_VER}/site-packages/

RUN   echo "/usr/local/libsbml/lib/${PYTHON_VER}/site-packages/libsbml" | tee /usr/local/lib/${PYTHON_VER}/dist-packages/libsbml.pth && \
      echo '/usr/local/libsbml/lib' | tee /etc/ld.so.conf.d/libsbml.conf && \
      ldconfig

RUN   cd tmp/libsbml/${libSBML_5} && make install 

# RUN   echo "/usr/local/libsbml/lib/python2.7/site-packages/libsbml" | tee /usr/local/lib/python2.7/dist-packages/libsbml.pth && \
#       echo '/usr/local/libsbml/lib' | tee /etc/ld.so.conf.d/libsbml.conf && \
#       ldconfig

#RUN   echo "/usr/local/libsbml/lib/python3.5/site-packages/libsbml" | tee /usr/local/lib/python3.5/dist-packages/libsbml.pth && \
#      echo "/usr/local/libsbml/lib" | tee /etc/ld.so.conf.d/libsbml.conf && \
#      ldconfig

#       mkdir -p /tmp/projects/libsbml/build_experimental && \
#       cd /tmp/projects/libsbml && svn co https://svn.code.sf.net/p/sbml/code/branches/libsbml-experimental@20107 && \
#       cd /tmp/projects/libsbml/build_experimental && cmake -DCMAKE_INSTALL_PREFIX=/usr/local/libsbml -DENABLE_LAYOUT=OFF -DENABLE_RENDER=OFF -DWITH_PYTHON=ON -DWITH_BZIP2=OFF ../libsbml-experimental && \
#       cd /tmp/projects/libsbml/build_experimental && make -j4 && make install && \
#       echo "/usr/local/libsbml/lib/python2.7/site-packages/libsbml" | tee /usr/local/lib/python2.7/dist-packages/libsbml.pth && \
#       echo '/usr/local/libsbml/lib' | tee /etc/ld.so.conf.d/libsbml.conf && \
#       ldconfig

# ####################
# # Install RoadRunner
# RUN   apt-get install -y python-numpy swig llvm-3.4-dev libncurses5-dev && \
#       mkdir -p tmp/rr/build/thirdparty && \
#       mkdir -p tmp/rr/build/all && \
#       cd tmp/rr && git clone https://github.com/sys-bio/roadrunner.git && \
#       cd tmp/rr/roadrunner && git checkout tags/v1.2.6 && \
#       cd tmp/rr/build/thirdparty && cmake ../../roadrunner/third_party/ -DCMAKE_INSTALL_PREFIX=/usr/local/roadrunner/thirdparty && \
#       cd tmp/rr/build/thirdparty && make -j4 && make install && \
#       cd tmp/rr/build/all && cmake -DBUILD_PYTHON=ON -DBUILD_LLVM=ON -DBUILD_TESTS=ON -DCMAKE_INSTALL_PREFIX=/usr/local/roadrunner -DTHIRD_PARTY_INSTALL_FOLDER=/usr/local/roadrunner/thirdparty -DLLVM_CONFIG_EXECUTABLE=/usr/bin/llvm-config-3.4 -DBUILD_TEST_TOOLS=ON ../../roadrunner && \
#       cd tmp/rr/build/all && make -j4 && make install && \
#       # Adding to python search path
#       echo "/usr/local/roadrunner/site-packages" | tee /usr/local/lib/python2.7/dist-packages/rr.pth && \
#       echo "/usr/local/roadrunner/lib" | tee /etc/ld.so.conf.d/roadrunner.conf && \
#       ldconfig

# #####################
# # Install SBML2MATLAB
# RUN   mkdir -p /tmp/projects && \
#       cd /tmp/projects && \
#       cd /tmp/projects && git clone https://github.com/stanleygu/sbml2matlab.git && \
#       cd /tmp/projects/sbml2matlab && git checkout 5e79fd959757ea53e9e548c605e7fd1dbddc7af8 && \
#       mkdir -p /tmp/projects/sbml2matlab/build && \
#       cd /tmp/projects/sbml2matlab/build && cmake .. -DLIBSBML_INCLUDE_DIR=/usr/local/libsbml/include -DCMAKE_INSTALL_PREFIX=/usr/local/sbml2matlab -DWITH_LIBSBML_LIBXML=ON -DLIBSBML_LIBRARY=/usr/local/libsbml/lib/libsbml-static.a -DWITH_PYTHON=ON -DCMAKE_CXX_FLAGS='-fPIC' && \
#       cd /tmp/projects/sbml2matlab/build && make -j4 && make install && \
#       echo '/usr/local/sbml2matlab/lib/python2.7/site-packages' | tee /usr/local/lib/python2.7/dist-packages/sbml2matlab.pth && \
#       echo '/usr/local/sbml2matlab' | tee /etc/ld.so.conf.d/sbml2matlab.conf && \
#       mv /usr/local/sbml2matlab/lib/python/site-packages/__init__.py /usr/local/sbml2matlab/lib/python2.7/site-packages/sbml2matlab && \
#       ldconfig

# ##################
# # Install antimony
# RUN   apt-get install -y -q wget && \
#       cd /tmp/projects && svn checkout https://svn.code.sf.net/p/antimony/code@3523 antimony-code && \
#       mkdir -p /tmp/projects/antimony-code/antimony/build && \
#       cd /tmp/projects/antimony-code/antimony/build && cmake .. -DWITH_PYTHON=ON -DLIBSBML_INCLUDE_DIR=/usr/local/libsbml/include -DCMAKE_INSTALL_PREFIX=/usr/local/antimony -DLIBSBML_LIBRARY=/usr/local/libsbml/lib/libsbml.so -DWITH_QTANTIMONY=OFF -DWITH_CELLML=OFF -DWITH_COMP_SBML=OFF && \
#       cd /tmp/projects/antimony-code/antimony/build && make -j4 && \
#       cd /tmp/projects/antimony-code/antimony/build && make install && \
#       mv /python2.7 /usr/local/antimony && \
#       echo '/usr/local/antimony/python2.7/site-packages/antimony' | tee /usr/local/lib/python2.7/dist-packages/libantimony.pth && \
#       echo '/usr/local/antimony/lib' | tee /etc/ld.so.conf.d/antimony.conf && \
#       ldconfig


# ##################
# # Install libsedml
# RUN   mkdir -p /tmp/projects && \
#       cd /tmp/projects && git clone https://github.com/fbergmann/libSEDML.git libsedml && \
#       cd /tmp/projects/libsedml && git checkout 7c33ef90866e07981021eabcd985b0aa19b513cf && \
#       mkdir -p /tmp/projects/libsedml/build && \
#       cd /tmp/projects/libsedml/build && cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local/libsedml -DLIBSBML_LIBRARY=/usr/local/libsbml/lib/libsbml-static.a -DLIBSBML_INCLUDE_DIR=/usr/local/libsbml/include -DEXTRA_LIBS=xml2 -DWITH_PYTHON=ON && \
#       cd /tmp/projects/libsedml/build && make -j4 && \
#       cd /tmp/projects/libsedml/build && make install && \
#       echo '/usr/local/libsedml/lib/python2.7/site-packages/libsedml' | tee /usr/local/lib/python2.7/dist-packages/libsedml.pth && \
#       echo '/usr/local/libsedml/lib' | tee /etc/ld.so.conf.d/libsedml.conf && \
#       ldconfig

# ##################
# # Install sedml2py
# RUN   cd /usr/local && git clone https://github.com/kirichoi/sedml2py.git && \
#       cd /usr/local/sedml2py && git checkout b9d7fd4ed17fbab18e887f07b179712dbbd8fd9a && \
#       echo "/usr/local/sedml2py" | tee /usr/local/lib/python2.7/dist-packages/sedml2py.pth

# ##################
# # PIP
# RUN   pip install virtualenv virtualenvwrapper && \
#       su user -c "source /usr/local/bin/virtualenvwrapper.sh; mkvirtualenv --system-site-packages localpy"

# ##################
# # Install pysces
# RUN   apt-get install -y -q gfortran python-scipy && \
#       pip install pysces==0.9.0

# ##################
# # Install stats packages
# RUN   pip install pandas==0.13.1 patsy==0.2.1 &&\
#       pip install statsmodels==0.5.0

# ##################
# # Install IPython
# RUN   easy_install -U distribute
# RUN   apt-get update -qq &&\
#       apt-get install -y -q libfreetype6-dev libpng-dev python-pygraphviz && \
#       pip install ipython[notebook]==2.1.0 matplotlib==1.4.0 brewer2mpl==1.4.1 prettyplotlib==0.1.7 mpld3==0.2

# ##################
# # Other packages
# RUN   pip install stochpy==1.1.2 networkx==1.8.1 zerorpc==0.4.4 notebooktools==0.3.1 simworker==0.0.8 celery==3.1.15 redis==2.10.3 bioservices==1.3.2

# ##################
# # Install tellurium
# RUN   pip install --upgrade git+https://github.com/stanleygu/tellurium.git

# ##################
# # Clean up
# RUN   rm -rf /tmp/projects /tmp/rr

CMD ["/bin/bash"]


