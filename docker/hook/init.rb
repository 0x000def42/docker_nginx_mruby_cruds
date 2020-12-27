module Xdef42
  class Request

    attr_reader :env, :params, :rendered
    def initialize app, env
      @app = app
      @env = env
      if env["REQUEST_METHOD"] == "POST" && env['rack.input']
        @params = JSON.parse env['rack.input']
      else
        @params = {}
      end
      @rendered = false
    end

    def db
      @app.db
    end

    def rendered?
      @rendered
    end

    def headers
      {'Content-Type' => 'application/json; charset=utf-8'}
    end

    def render code, content
      @rendered = true
      [code, headers, JSON.stringify(content)]
    end
  end

  module App
    METHODS = {
      GET: ::R3::GET,
      POST: ::R3::POST,
      PUT: ::R3::PUT,
      DELETE: ::R3::DELETE,
      PATCH: ::R3::PATCH,
      HEAD: ::R3::HEAD,
      OPTIONS: ::R3::OPTIONS,
    }

    def db
      @db ||= Redis.new("redis", 6379, 2).tap do |client|
        client.enable_keepalive
      end
    end

    def self.included(base)
      base.class_eval do
        @@routes = []

        def self.instance
          @instance ||= self.new
        end

        def self.routes
          @@routes
        end

        METHODS.each do |sym, int|
          self.define_singleton_method(sym.downcase) do |path, &block|
            @@routes.push({method: int, path: path, block: block})
          end
        end
      end
    end

    def initialize
      routes = self.class.routes
      @tree = ::R3::Tree.new(routes.length)
      routes.each do |route|
        @tree.add(route[:path], route[:method], route[:block])
      end
      @tree.compile
    end

    def call env
      method = METHODS[env['REQUEST_METHOD'].intern]
      match = @tree.match(env['PATH_INFO'], method)
      if match
        request = Request.new(self, env)
        response = request.instance_exec(*match[0], &match[1])
        if request.rendered?
          response
        else
          [200,
            {'Content-Type' => 'text/plain; charset=utf-8'},
            "'render' not called in #{env['REQUEST_METHOD']} '#{env['PATH_INFO']}'"
          ]
        end
      else
        not_found
      end
    end

    def not_found
      [404,
      {'Content-Type' => 'text/plain; charset=utf-8'},
      ["Not Found"]
      ]
    end
  end
end

module Kernel
  def run obj
    begin
      hout = Nginx::Headers_out.new
      r = Nginx::Request.new
      input = (r.method == "POST" || r.method == "PUT") ? r.body : ""
      env = {
        "REQUEST_METHOD"    => r.method,
        "SCRIPT_NAME"       => "",
        "PATH_INFO"         => r.uri,
        "REQUEST_URI"       => r.unparsed_uri,
        "QUERY_STRING"      => r.args,
        "SERVER_NAME"       => r.hostname,
        # "SERVER_ADDR"       => c.local_ip,
        # "SERVER_PORT"       => c.local_port.to_s,
        # "REMOTE_ADDR"       => c.remote_ip,
        # "REMOTE_PORT"       => c.remote_port.to_s,
        "rack.url_scheme"   => r.scheme,
        "rack.multithread"  => false,
        "rack.multiprocess" => true,
        "rack.run_once"     => false,
        "rack.hijack?"      => false,
        "server.version"    => Nginx.server_version,
        "rack.input"       => input,
      }
      call_res = obj.call(env)
      call_res[1].each do |k,v|
        hout[k] = v
      end
      Nginx.rputs call_res[2]
      Nginx.return call_res[0]
    rescue => e
      puts e.message + "\n" + e.backtrace.join("\n")
      Nginx.return 500
      # Nginx.echo e.message + e.backtrace.join(" ")
    end
  end
end

class PostRepository

  def all

  end

  def find id
    db.hgetall("posts:id:#{id}")
  end

  def create args
    db = App.instance.db
    db.queue('eval', <<-LUA, 3, 'posts', 0, 2, 'title', 'Title', 'content', 'Content')
      local collection = KEYS[1]
      local indexesCount = tonumber(KEYS[2])
      local fieldsCount = tonumber(KEYS[3])

      
      local id = redis.call("incr", collection .. ':pk_inc')

      local indexI = 1
      while indexI <= indexesCount do

        local indexName = ARGV[indexI * 2 - 1]
        local indexValue = ARGV[indexI * 2]

        redis.call("zadd", collection .. ':index:' .. indexName, 0, indexValue..":"..id)

        indexI = indexI + 1
      end
      redis.call('hmset', 'posts' .. ':id:' .. id, unpack(ARGV))

      return {"id", id, unpack(ARGV)}
    LUA
    response = db.reply
    i = 0
    serialized = {}
    while i < response.size / 2 do
      serialized[response[i*2]] = response[i * 2 + 1]
      i+=1
    end
    serialized
  end

  def update id, args

  end

  def delete id

  end

end

class App
  include Xdef42::App
  get "/" do
    post = PostRepository.new.create({title: "Title", content: "Content"})
    render 200, post
  end

  get "/posts" do
    posts = PostRepository.new.all
    render 200, posts
  end

  post "/posts" do
    
    if post = PostRepository.new.create(params)
      render 200, post
    else
      render 200, {errors: ["Validation failed"]}
    end
  end

  get "/posts/{id}" do |id|
    if post = PostRepository.find(id)
      render 200, post
    else
      render 200, {errors: ["Not found"]}
    end
  end

  patch "/posts/{id}" do |id|
    if post = PostRepository.find(id)
      if post = PostRepository.new.update(id, params)
        render 200, post
      else
        render 200, {errors: ["Validation failed"]}
      end
    else
      render 200, {errors: ["Not found"]}
    end
  end

  delete "/posts/{id}" do |id|
    if post = PostRepository.find(id)
      PostRepository.new.delete(id)
      render 204, {}
    else
      render 200, {errors: ["Not found"]}
    end
  end
end