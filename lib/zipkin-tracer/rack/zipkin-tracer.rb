require 'rack'
require 'finagle-thrift/trace'
require 'finagle-thrift/tracer'
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
     Trace::BinaryAnnotation::PATH => PATH_INFO
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
        if !trace_id.sampled? || !routable_request?(env)
          @app.call(env)
        else
          @tracer.with_new_span(trace_id, env[REQUEST_METHOD].to_s.downcase) do |span|
            trace!(span, zipkin_env) { @app.call(env) }
          end
        end
      end
    end

    private

    def routable_request?(env)
      Application.routable_request?(env[PATH_INFO],  env[REQUEST_METHOD])
    end

    def annotate_plugin(env, status, response_headers, response_body)
      @config.annotate_plugin.call(env, status, response_headers, response_body) if @config.annotate_plugin
    end

    def trace!(span, zipkin_env, &block)
      # if the request comes from a non zipkin-enabled source record the default tags
      tags = DEFAULT_SERVER_RECV_TAGS unless zipkin_env.called_with_zipkin_headers?
      # if the user specified tags to record on server recv, use these no matter what
      tags = @config.record_on_server_receive if @config.record_on_server_receive
      trace_request_information(span, zipkin_env.env, tags)

      span.record(Trace::Annotation::SERVER_RECV)
      span.record('whitelisted') if zipkin_env.force_sample?
      status, headers, body = yield
    ensure
      annotate_plugin(zipkin_env.env, status, headers, body)
      span.record(Trace::Annotation::SERVER_SEND)
    end

    def trace_request_information(span, env, tags)
      return if tags.nil?
      tags.each { |annotation_key, env_key| span.record_tag(annotation_key, env[env_key]) }
    end
  end
end
