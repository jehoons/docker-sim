# FROM       ubuntu:16.04
ARG BASE_IMAGE
FROM jhsong/essential:${BASE_IMAGE} 
ARG BASE_IMAGE
RUN echo "base image: ${BASE_IMAGE}"

MAINTAINER Je-Hoon Song "song.jehoon@gmail.com"

# install additional packages 

# tellurirum 
RUN pip install tellurium

RUN cpan -i Class::Std

COPY fastfacile /usr/local/fastfacile

RUN cd /usr/local/fastfacile/deps && \
    wget -O gsl-2.2.tar.gz https://ndownloader.figshare.com/files/10838513 && \
    tar xvf gsl-2.2.tar.gz

RUN cd /usr/local/fastfacile/deps/gsl-2.2 && ./configure --with-cflags="-O4 -fPIC" --prefix=/usr/local/gsl-2.2
RUN cd /usr/local/fastfacile/deps/gsl-2.2 && make clean && make -j 20 

RUN cd /usr/local/fastfacile/deps && \
    wget -O sundials-2.3.0.tar.gz  https://ndownloader.figshare.com/files/10838510 && \
    tar xvf sundials-2.3.0.tar.gz

RUN cd /usr/local/fastfacile/deps/sundials-2.3.0 && \
    ./configure --with-cflags="-O4 -fPIC" --prefix=/usr/local/sundials-2.3.0

RUN cd /usr/local/fastfacile/deps/sundials-2.3.0 && \
    make clean && make -j 20 && make install 

RUN cd /usr/bin && \
    wget -O vfgen https://ndownloader.figshare.com/files/10838516 && \
    chmod +x vfgen 

RUN cd /home && wget http://downloads.sourceforge.net/project/boost/boost/1.58.0/boost_1_58_0.tar.gz \
  && tar xfz boost_1_58_0.tar.gz \
  && rm boost_1_58_0.tar.gz \
  && cd boost_1_58_0 \
  && ./bootstrap.sh --prefix=/usr/local --with-libraries=program_options \
  && ./b2 install \
  && cd /home \
  && rm -rf boost_1_58_0

RUN apt-get update && apt-get install cmake-curses-gui

RUN pip install deap scoop

ENV PATH /usr/local/fastfacile/bin:/usr/local/fastfacile/facile:$PATH

ENV PYTHONPATH $PYTHONPATH:/usr/local/lib/python3.5/dist-packages:/root/share

ENV PS1="\[\033[1;34m\]\!\[\033[0m\] \[\033[1;35m\]sysbio\[\033[0m\]:\[\033[1;35m\]\W\[\033[0m\]$ "

RUN echo "export PATH=${PATH}:\$PATH" >> /root/.bashrc
RUN echo "export PS1=\"${PS1}\"" >> /root/.bashrc

VOLUME /root

EXPOSE 8888 

COPY docker-entrypoint.sh /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"] 

CMD ["startup"]

