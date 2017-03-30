require 'finagle-thrift/trace'
require 'finagle-thrift/tracer'
require 'uri'
require 'excon'

module ZipkinTracer
  class ExconHandler < Excon::Middleware::Base
    def initialize(_)
      super
    end

    def error_call(datum)
      super(datum)
    end

    def request_call(datum)
      trace_id = TraceGenerator.new.next_trace_id

      TraceContainer.with_trace_id(trace_id) do
        b3_headers.each do |method, header|
          datum[:headers][header] = trace_id.send(method).to_s
        end

        trace!(datum, trace_id) if Trace.tracer && trace_id.sampled?
      end

      super(datum)
    end

    def response_call(datum)
      if span = datum[:span]
        if status = response_status(datum)
          span.record_tag(
            Trace::BinaryAnnotation::STATUS,
            status,
            Trace::BinaryAnnotation::Type::STRING,
            local_endpoint
          )
        end
        span.record(Trace::Annotation::CLIENT_RECV, local_endpoint)
      end

      super(datum)
    end

    private

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

    def local_endpoint
      Trace.default_endpoint # The rack middleware set this up for us.
    end

    def remote_endpoint(url, service_name)
      Trace::Endpoint.remote_endpoint(url, service_name, local_endpoint.ip_format) # The endpoint we are calling.
    end

    def service_name(datum, default)
      datum.fetch(:zipkin_service_name, default)
    end

    def response_status(datum)
      datum[:response] && datum[:response][:status] && datum[:response][:status].to_s
    end

    def trace!(datum, trace_id)
      url_string = Excon::Utils::request_uri(datum)
      url = URI(url_string)
      service_name = service_name(datum, url.host)

      Trace.tracer.with_new_span(trace_id, datum[:method].to_s.downcase) do |span|
        # annotate with method (GET/POST/etc.) and uri path
        span.record_tag(Trace::BinaryAnnotation::PATH, url.path, Trace::BinaryAnnotation::Type::STRING, local_endpoint)
        span.record_tag(Trace::BinaryAnnotation::SERVER_ADDRESS, SERVER_ADDRESS_SPECIAL_VALUE, Trace::BinaryAnnotation::Type::BOOL, remote_endpoint(url, service_name))
        span.record(Trace::Annotation::CLIENT_SEND, local_endpoint)

        # store the span in the datum hash so it can be used in the response_call
        datum[:span] = span
      end
    rescue ArgumentError, URI::Error => e
      # Ignore URI errors, don't trace if there is no URI
    end
  end
end
