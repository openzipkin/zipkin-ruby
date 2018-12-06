require 'faraday'
require 'finagle-thrift/trace'
require 'finagle-thrift/tracer'
require 'uri'

module ZipkinTracer
  # Faraday middleware. It will add CR/CS annotations to outgoing connections done by Faraday
  class FaradayHandler < ::Faraday::Middleware
    def initialize(app, service_name = nil)
      @app = app
      @service_name = service_name
    end

    def call(env)
      trace_id = TraceGenerator.new.next_trace_id
      TraceContainer.with_trace_id(trace_id) do
        b3_headers.each do |method, header|
          env[:request_headers][header] = trace_id.send(method).to_s
        end
        if Trace.tracer && trace_id.sampled?
          trace!(env, trace_id)
        else
          @app.call(env)
        end
      end
    end

    private

    SERVER_ADDRESS_SPECIAL_VALUE = '1'.freeze
    STATUS_ERROR_REGEXP = /\A(4.*|5.*)\z/.freeze


    def b3_headers
      {
        trace_id: 'X-B3-TraceId',
        parent_id: 'X-B3-ParentSpanId',
        span_id: 'X-B3-SpanId',
        sampled: 'X-B3-Sampled',
        flags: 'X-B3-Flags'
      }
    end

    def trace!(env, trace_id)
      response = nil
      # handle either a URI object (passed by Faraday v0.8.x in testing), or something string-izable
      method = env[:method].to_s
      url = env[:url].respond_to?(:host) ? env[:url] : URI.parse(env[:url].to_s)
      local_endpoint = Trace.default_endpoint # The rack middleware set this up for us.
      remote_endpoint = Trace::Endpoint.remote_endpoint(url, @service_name, local_endpoint.ip_format) # The endpoint we are calling.
      Trace.tracer.with_new_span(trace_id, method.downcase) do |span|
        @span = span # So we can record on exceptions
        # annotate with method (GET/POST/etc.) and uri path
        span.record_tag(Trace::BinaryAnnotation::METHOD, method.upcase, Trace::BinaryAnnotation::Type::STRING, local_endpoint)
        span.record_tag(Trace::BinaryAnnotation::PATH, url.path, Trace::BinaryAnnotation::Type::STRING, local_endpoint)
        span.record_tag(Trace::BinaryAnnotation::SERVER_ADDRESS, SERVER_ADDRESS_SPECIAL_VALUE, Trace::BinaryAnnotation::Type::BOOL, remote_endpoint)
        span.record(Trace::Annotation::CLIENT_SEND, local_endpoint)
        response = @app.call(env).on_complete do |renv|
          record_response_tags(span, renv[:status].to_s, local_endpoint)
        end
        span.record(Trace::Annotation::CLIENT_RECV, local_endpoint)
      end
      response
    rescue Net::ReadTimeout
      record_error(@span, 'Request timed out.', local_endpoint)
      raise
    rescue Faraday::ConnectionFailed
      record_error(@span, 'Request connection failed.', local_endpoint)
      raise
    rescue Faraday::ClientError
      record_error(@span, 'Generic Faraday client error.', local_endpoint)
      raise
    end

    def record_error(span, msg, local_endpoint)
      span.record_tag(Trace::BinaryAnnotation::ERROR, msg, Trace::BinaryAnnotation::Type::STRING, local_endpoint)
    end

    def record_response_tags(span, status, local_endpoint)
      span.record_tag(Trace::BinaryAnnotation::STATUS, status, Trace::BinaryAnnotation::Type::STRING, local_endpoint)
      if STATUS_ERROR_REGEXP.match(status)
        span.record_tag(Trace::BinaryAnnotation::ERROR, status,
          Trace::BinaryAnnotation::Type::STRING, local_endpoint)
      end
    end

  end
end
