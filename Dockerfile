FROM ubuntu:18.04
MAINTAINER matsumotory

RUN apt-get -y update
RUN apt-get -y install sudo openssh-server
RUN apt-get -y install git
RUN apt-get -y install curl
RUN apt-get -y install rake
RUN apt-get -y install ruby ruby-dev
RUN apt-get -y install bison
RUN apt-get -y install libcurl4-openssl-dev libssl-dev
RUN apt-get -y install libhiredis-dev
RUN apt-get -y install libmarkdown2-dev
RUN apt-get -y install libcap-dev
RUN apt-get -y install libcgroup-dev
RUN apt-get -y install make
RUN apt-get -y install libpcre3 libpcre3-dev
RUN apt-get -y install libmysqlclient-dev
RUN apt-get -y install gcc

RUN cd /usr/local/src/ && git clone https://github.com/matsumotory/ngx_mruby.git
ENV NGINX_CONFIG_OPT_ENV --with-http_stub_status_module --with-http_ssl_module --prefix=/usr/local/nginx --with-http_realip_module --with-http_addition_module --with-http_sub_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_random_index_module --with-http_secure_link_module
# COPY . /usr/local/src/ngx_mruby
COPY ./build_config.rb /usr/local/src/ngx_mruby/build_config.rb
RUN cd /usr/local/src/ngx_mruby && sh build.sh
RUN cd /usr/local/src/ngx_mruby && make install

EXPOSE 80
EXPOSE 443

ADD docker/hook /usr/local/nginx/hook
ADD docker/conf /usr/local/nginx/conf
ADD docker/conf/nginx.conf /usr/local/nginx/conf/nginx.conf

WORKDIR /usr/local/nginx/sbin
ENTRYPOINT ["./nginx", "-g", "daemon off;"]