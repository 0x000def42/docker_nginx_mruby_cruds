
module Xdef42
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

    def self.included(base)
      base.class_eval do
        @@routes = []

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
      @env = env
      method = METHODS[@env['REQUEST_METHOD'].intern]
      match = @tree.match(@env['PATH_INFO'], method)
      return instance_exec(*match[0], &match[1]) if match
      not_found
    end

    def self.run
      App.new
    end

    def headers
      {'Content-Type' => 'application/json; charset=utf-8'}
    end

    def render code, content
      [code, headers, JSON.stringify(content)]
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
      call_res = obj.call({'REQUEST_METHOD' => r.method, 'PATH_INFO' => r.unparsed_uri})
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