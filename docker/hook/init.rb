module Xdef42
  class Request

    attr_reader :env, :params, :rendered
    def initialize app, env
      @app = app
      @env = env
      if env["REQUEST_METHOD"] == "POST"
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
      @db ||= Redis.new("redis", 6379, 2)    
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
      Nginx.echo call_res[2]
      Nginx.return call_res[0]
    rescue => e
      Nginx.echo e.message + e.backtrace.join(" ")
    end
  end
end