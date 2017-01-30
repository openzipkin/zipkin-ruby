require 'finagle-thrift/trace'
require 'finagle-thrift/tracer'
require 'uri'
require 'excon'

module ZipkinTracer
  class ExconHandler < Excon::Middleware::Base
    def initialize(stack)
      # Excon does not currently provide a way to parameterize middlewares.
      @service_name = ENV.fetch('ZIPKIN_SERVICE_NAME', 'unknown-service')
      super
    end

    def error_call(datum)
      # do stuff
      puts "error call"
      super(datum)
    end

    def request_call(datum)
      puts "request call"
      trace_id = TraceGenerator.new.next_trace_id

      TraceContainer.with_trace_id(trace_id) do
        b3_headers.each do |method, header|
          datum[:headers][header] = trace_id.send(method).to_s
        end

        trace!(datum, trace_id)
      end

      byebug

      result = super(datum)
      byebug
      result
    end

    def response_call(datum)
      puts "response call"
      response = datum[:response]
      local_endpoint = Trace.default_endpoint # The rack middleware set this up for us.

      if span = datum[:span]
        span.record_tag(Trace::BinaryAnnotation::STATUS, response[:status].to_s, Trace::BinaryAnnotation::Type::STRING, local_endpoint)
        span.record(Trace::Annotation::CLIENT_RECV, local_endpoint)
      end

      super(datum)
    end

    SERVER_ADDRESS_SPECIAL_VALUE = '1'.freeze

    def b3_headers
      {
        trace_id: 'X-B3-TraceId',
        parent_id: 'X-B3-ParentSpanId',
        span_id: 'X-B3-SpanId',
        sampled: 'X-B3-Sampled',
        flags: 'X-B3-Flags'
      }
    end

    def trace!(datum, trace_id)
      url = datum[:url].respond_to?(:host) ? datum[:url] : URI.parse(datum[:url].to_s)
      local_endpoint = Trace.default_endpoint # The rack middleware set this up for us.
      remote_endpoint = Trace::Endpoint.remote_endpoint(url, @service_name, local_endpoint.ip_format) # The endpoint we are calling.

      Trace.tracer.with_new_span(trace_id, datum[:method].to_s.downcase) do |span|
        # annotate with method (GET/POST/etc.) and uri path
        span.record_tag(Trace::BinaryAnnotation::PATH, url.path, Trace::BinaryAnnotation::Type::STRING, local_endpoint)
        span.record_tag(Trace::BinaryAnnotation::SERVER_ADDRESS, SERVER_ADDRESS_SPECIAL_VALUE, Trace::BinaryAnnotation::Type::BOOL, remote_endpoint)
        span.record(Trace::Annotation::CLIENT_SEND, local_endpoint)

        datum[:span] = span
      end
    end
  end
end
