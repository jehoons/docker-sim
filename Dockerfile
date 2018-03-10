FROM ubuntu:16.04
# Je-Hoon Song <song.jehoon@gmail.com> 

ENV DEBIAN_FRONTEND="noninteractive"

RUN apt-get update && \
    apt-get install -y openjdk-8-jdk && \
    apt-get install -y ant && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /var/cache/oracle-jdk8-installer;

# Fix certificate issues, found as of 
# https://bugs.launchpad.net/ubuntu/+source/ca-certificates-java/+bug/983302
RUN apt-get update && \
    apt-get install -y ca-certificates-java && \
    apt-get clean && \
    update-ca-certificates -f && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /var/cache/oracle-jdk8-installer;

# Setup JAVA_HOME, this is useful for docker commandline
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64/
RUN export JAVA_HOME

# neo4j 
RUN apt-get update && apt-get install -y bash curl
ENV NEO4J_SHA256=0e5c6492cd274edf06c5f10d2b64711bd559aaff37c646e03bfa65e613994174 \
    NEO4J_TARBALL=neo4j-community-3.3.1-unix.tar.gz \
    NEO4J_EDITION=community
ARG NEO4J_URI=http://dist.neo4j.org/neo4j-community-3.3.1-unix.tar.gz
RUN curl --fail --silent --show-error --location --remote-name ${NEO4J_URI} \
    && echo "${NEO4J_SHA256}  ${NEO4J_TARBALL}" | sha256sum -cw - \
    && tar --extract --file ${NEO4J_TARBALL} --directory /var/lib \
    && mv /var/lib/neo4j-* /var/lib/neo4j \
    && rm ${NEO4J_TARBALL} \
    && mv /var/lib/neo4j/data /data \
    && ln -s /data /var/lib/neo4j/data
ENV PATH /var/lib/neo4j/bin:$PATH

WORKDIR /root

VOLUME /data

# python 3 
RUN apt-get update \
  && apt-get install -y python3-pip python3-dev \
  && cd /usr/local/bin \
  && ln -s /usr/bin/python3 python \
  && pip3 install --upgrade pip
RUN pip install cycli 
RUN pip install flask flask_cors
RUN pip install telepot

# editors 
RUN apt-get update && apt-get install -y nano
RUN apt-get update && apt-get install -y build-essential git curl wget bash-completion openssh-server gfortran sudo make \
    cmake libssl-dev libreadline-dev llvm libsqlite3-dev libmysqlclient-dev python-dev \
    python3-dev zlib1g-dev libbz2-dev language-pack-ko

RUN mkdir tmp && \
    wget -O tmp/vim.tar.gz https://ndownloader.figshare.com/files/10597954 
RUN cd tmp && tar xvfz vim.tar.gz 
RUN cd tmp/vim && ./configure --with-features=huge \
		--enable-multibyte \
		--enable-rubyinterp \
		--enable-pythoninterp=dynamic \
		--with-python-config-dir=/usr/lib/python2.7/config-x86_64-linux-gnu \
		--enable-python3interp=dynamic \
		--with-python3-config-dir=/usr/lib/python3.5/config-3.5m-x86_64-linux-gnu \
		--disable-gui --enable-cscope --prefix=/usr
RUN cd tmp/vim && make VIMRUNTIMEDIR=/usr/share/vim/vim80 && make -j4 install
COPY local-package/neobundle.sh tmp/neobundle.sh  
RUN cd tmp && sh ./neobundle.sh 
COPY local-package/supertab.vmb tmp/supertab.vmb 
RUN cd tmp && vim -c 'so %' -c 'q' supertab.vmb 
COPY .vim /root/.vim
COPY .vimrc /root/.vimrc
RUN mkdir -p /root/.vim/autoload /root/.vim/bundle && \
    curl -LSso /root/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim
RUN cd /root/.vim/bundle && git clone git://github.com/neo4j-contrib/cypher-vim-syntax.git

# etc 
RUN apt-get update && apt-get install -y \
    net-tools sudo locales 
RUN locale-gen en_US.UTF-8
RUN apt-get update && apt-get install -y mailutils ssmtp
RUN apt-get update && apt-get install -y rubygems rubygems-integration ruby
RUN gem install asciidoctor
RUN gem install tilt

RUN pip install meinheld

RUN apt-get update && apt-get install -y --no-install-recommends \
		apache2 && rm -r /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y git 

# notebook 
RUN pip install jupyter jupyterlab
RUN mkdir -p -m 700 /root/.jupyter/ 
RUN pip install jupyterthemes
RUN pip install --upgrade jupyterthemes
RUN jupyter serverextension enable --py jupyterlab --sys-prefix
RUN pip install matplotlib-venn sympy sklearn 
COPY config/requirements.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt 

# tellurirum 
RUN pip install tellurium

ARG IPADDR=localhost
ENV STANDB_IPADDR=${IPADDR}

# jupyter
EXPOSE 8888

# mail 
ADD config/ssmtp.conf /etc/ssmtp/ssmtp.conf
COPY .bashrc /root/.bashrc
COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY ./local-package/* /tmp/
COPY config/jupyter_notebook_config.py /root/.jupyter/

ENV PATH /usr/local/neo4j-guide:$PATH
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8

RUN rm -rf tmp

ENTRYPOINT ["/docker-entrypoint.sh"]

# CMD ["neo4j"]
CMD ["startup"]

