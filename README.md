# Dockerized nginx mruby + redis cruds

Challenge!!

Get 10rps on crud operations on 1 "Model".

Buissnes login on mruby in core of nginx.
Redis as database :)

Test with wrk -t4 -c400 -d100s http://localhost:1000

Clear nginx "Hello world" page with default settings and without docker returns 125k rps.
Optimized nginx with mruby in docker with `return 200 "Hello"` has 90k rps.
Optimized nginx with mruby in docker with mruby file directives that call init class instance and print "Hello" string has 85k rps.

Added bindings to C lib r3 with familiar route style slow down rps to 60K.
Added redis client and write and read simple hash into json string slow rps down to 20k.

Added per request isolation params and env, read body.

Append creating logic into stored redis procedure on lua with increment id, filling indexes now rps in 16k on create post