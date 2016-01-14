require 'faraday'
require 'finagle-thrift/trace'
require 'finagle-thrift/tracer'
require 'uri'

module ZipkinTracer
  class FaradayHandler < ::Faraday::Middleware
    B3_HEADERS = {
      trace_id: 'X-B3-TraceId',
      parent_id: 'X-B3-ParentSpanId',
      span_id: 'X-B3-SpanId',
      sampled: 'X-B3-Sampled',
      flags: 'X-B3-Flags'
    }.freeze

    def initialize(app, service_name = nil)
      @app = app
      @service_name = service_name
      @tracer = Trace.tracer
    end

    def call(env)
      trace_id = Trace.id.next_id
      with_trace_id(trace_id) do
        B3_HEADERS.each do |method, header|
          env[:request_headers][header] = trace_id.send(method).to_s
        end
        if trace_id.sampled?
          trace!(env, trace_id)
        else
          @app.call(env)
        end
      end
    end

    private
    SERVER_ADDRESS = 'sa'
    SERVER_ADDRESS_SPECIAL_VALUE = '1'
    STRING_TYPE = 'STRING'
    BOOLEAN_TYPE = 'BOOL'
    URI_KEY = 'http.uri'
    STATUS_KEY = 'http.status'
    UNKNOWN_URL = 'unknown'


    def trace!(env, trace_id)
      response = nil
      # handle either a URI object (passed by Faraday v0.8.x in testing), or something string-izable
      url = env[:url].respond_to?(:host) ? env[:url] : URI.parse(env[:url].to_s)
      local_endpoint = Trace.default_endpoint # The rack middleware set this up for us.
      remote_endpoint = callee_endpoint(url, local_endpoint.ip_format) # The endpoint we are calling.
      # annotate with method (GET/POST/etc.) and uri path
      @tracer.set_rpc_name(trace_id, env[:method].to_s.downcase)
      @tracer.record(trace_id, Trace::BinaryAnnotation.new(URI_KEY, url.path, STRING_TYPE, local_endpoint))
      @tracer.record(trace_id, Trace::BinaryAnnotation.new(SERVER_ADDRESS, SERVER_ADDRESS_SPECIAL_VALUE, BOOLEAN_TYPE, remote_endpoint))
      @tracer.record(trace_id, Trace::Annotation.new(Trace::Annotation::CLIENT_SEND, local_endpoint))
      response = @app.call(env).on_complete do |renv|
        # record HTTP status code on response
        @tracer.record(trace_id, Trace::BinaryAnnotation.new(STATUS_KEY, renv[:status].to_s, STRING_TYPE, local_endpoint))
      end
      @tracer.record(trace_id, Trace::Annotation.new(Trace::Annotation::CLIENT_RECV, local_endpoint))
      response
    end

    def with_trace_id(trace_id, &block)
      Trace.push(trace_id)
      yield
    ensure
      Trace.pop
    end

    def callee_endpoint(url, ip_format)
      service_name = @service_name || url.host.split('.').first || UNKNOWN_URL # default to url-derived service name
      Trace::Endpoint.make_endpoint(url.host, url.port, service_name, ip_format)
    end
  end
end
