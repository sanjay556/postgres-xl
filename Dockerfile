FROM centos:7 
Maintainer "Sanjay556@yahoo.com"

RUN yum install git -y \
  && git clone git://git.postgresql.org/git/postgres-xl.git \
  && cd postgres-xl \
  && ./configure \
  && make -j4 \
  && make install \
  && cd contrib \
  && make -j4 \
  && sudo make install \

CMD [ "sleep", "9000"]
