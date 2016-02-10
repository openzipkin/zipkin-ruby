require 'faraday'
require 'finagle-thrift/trace'
require 'finagle-thrift/tracer'
require 'uri'

module ZipkinTracer
  # Faraday middleware. It will add CR/CS annotations to outgoing connections done by Faraday
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
    end

    def call(env)
      trace_id = Trace.id.next_id
      Trace.with_trace_id(trace_id) do
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
    SERVER_ADDRESS_SPECIAL_VALUE = '1'.freeze

    def trace!(env, trace_id)
      response = nil
      # handle either a URI object (passed by Faraday v0.8.x in testing), or something string-izable
      url = env[:url].respond_to?(:host) ? env[:url] : URI.parse(env[:url].to_s)
      local_endpoint = Trace.default_endpoint # The rack middleware set this up for us.
      remote_endpoint = Trace::Endpoint.remote_endpoint(url, @service_name, local_endpoint.ip_format) # The endpoint we are calling.
      Trace.tracer.with_new_span(trace_id, env[:method].to_s.downcase) do |span|
        # annotate with method (GET/POST/etc.) and uri path
        span.record_tag(Trace::BinaryAnnotation::URI, url.path, Trace::BinaryAnnotation::Type::STRING, local_endpoint)
        span.record_tag(Trace::BinaryAnnotation::SERVER_ADDRESS, SERVER_ADDRESS_SPECIAL_VALUE, Trace::BinaryAnnotation::Type::BOOL, remote_endpoint)
        span.record(Trace::Annotation::CLIENT_SEND, local_endpoint)
        response = @app.call(env).on_complete do |renv|
          # record HTTP status code on response
          span.record_tag(Trace::BinaryAnnotation::STATUS, renv[:status].to_s, Trace::BinaryAnnotation::Type::STRING, local_endpoint)
        end
        span.record(Trace::Annotation::CLIENT_RECV, local_endpoint)
      end
      response
    end

  end
end
