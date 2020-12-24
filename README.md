# Dockerized nginx mruby + redis cruds

Challenge!!

Get 10rps on crud operations on 1 "Model".

Buissnes login on mruby in core of nginx.
Redis as database :)

Clear nginx "Hello world" page with default settings and without docker returns 125k rps.
Optimized nginx with mruby in docker with `return 200 "Hello"` has 90k rps.
Optimized nginx with mruby in docker with mruby file directives that call init class instance and print "Hello" string has 85k rps.