require 'rack'
require 'zipkin-tracer/config'
require 'zipkin-tracer/tracer_factory'
require 'zipkin-tracer/rack/zipkin_env'

module ZipkinTracer
  # This middleware reads Zipkin headers from the request and sets/creates a Trace.id usable by the rest of the app
  # It will also send the trace to the Zipkin service using one of the methods configured.
  class RackHandler
    # the following constants are defined only from rack 1.6
    PATH_INFO = Rack::PATH_INFO rescue 'PATH_INFO'.freeze
    REQUEST_METHOD = Rack::REQUEST_METHOD rescue 'REQUEST_METHOD'.freeze

    DEFAULT_SERVER_RECV_TAGS = {
      Trace::Span::Tag::PATH => PATH_INFO
    }.freeze

    def initialize(app, config = nil)
      @app = app
      @config = Config.new(app, config).freeze
      @tracer = TracerFactory.new.tracer(@config)
    end

    def call(env)
      zipkin_env = ZipkinEnv.new(env, @config)
      trace_id = zipkin_env.trace_id
      TraceContainer.with_trace_id(trace_id) do
        return @app.call(env) unless trace_id.sampled?

        routable = routable_request?(env)
        return @app.call(env) unless (routable || additional_path?(env))

        @tracer.with_new_span(trace_id, span_name(env, routable)) do |span|
          trace!(span, zipkin_env) { @app.call(env) }
        end
      end
    end

    private

    def routable_request?(env)
      Application.routable_request?(env[PATH_INFO], env[REQUEST_METHOD])
    end

    def additional_path?(env)
      @config.additional_paths && env[PATH_INFO].start_with?(*@config.additional_paths)
    end

    def span_name(env, routable)
      route = Application.get_route(env) if routable
      "#{env[REQUEST_METHOD].to_s.downcase} #{route}".strip
    end

    def annotate_plugin(span, env, status, response_headers, response_body)
      @config.annotate_plugin.call(span, env, status, response_headers, response_body) if @config.annotate_plugin
    end

    def trace!(span, zipkin_env, &block)
      trace_request_information(span, zipkin_env)
      span.kind = Trace::Span::Kind::SERVER
      span.record('whitelisted') if zipkin_env.force_sample?
      status, headers, body = yield
    ensure
      annotate_plugin(span, zipkin_env.env, status, headers, body)
    end

    def trace_request_information(span, zipkin_env)
      tags = if !@config.record_on_server_receive.empty?
        # if the user specified tags to record on server receive, use these no matter what
        @config.record_on_server_receive
      elsif !zipkin_env.called_with_zipkin_headers?
        # if the request comes from a non zipkin-enabled source record the default tags
        DEFAULT_SERVER_RECV_TAGS
      end
      return if tags.nil?
      tags.each { |annotation_key, env_key| span.record_tag(annotation_key, zipkin_env.env[env_key]) }
    end
  end
end
