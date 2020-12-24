# Ngx ruby dockerized

Minimal files to startup

Based on https://github.com/matsumotory/ngx_mruby

## Get it
1. `git clone git@github.com:0x000def42/docker_nginx_mruby.git`
2. `cd docker_nginx_mruby`
3. `docker build . -t docker_nginx_mruby`
4. `docker run -p 1000:80 docker_nginx_mruby`
5. ...
6. PROFIT

Open http://localhost:1000/mruby-hello