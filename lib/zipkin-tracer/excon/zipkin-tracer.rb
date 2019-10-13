require 'uri'
require 'excon'

module ZipkinTracer
  class ExconHandler < Excon::Middleware::Base
    include B3HeaderHelper

    def initialize(_)
      super
    end

    def error_call(datum)
      super(datum)
    end

    def request_call(datum)
      trace_id = TraceGenerator.new.next_trace_id

      TraceContainer.with_trace_id(trace_id) do
        set_b3_header(datum[:headers], trace_id)
        trace!(datum, trace_id) if Trace.tracer && trace_id.sampled?
      end

      super(datum)
    end

    def response_call(datum)
      if span = datum[:span]
        span.record_status(response_status(datum))
        Trace.tracer.end_span(span)
      end

      super(datum)
    end

    private

    def remote_endpoint(url, service_name)
      Trace::Endpoint.remote_endpoint(url, service_name) # The endpoint we are calling.
    end

    def service_name(datum, default)
      datum.fetch(:zipkin_service_name, default)
    end

    def response_status(datum)
      datum[:response] && datum[:response][:status] && datum[:response][:status].to_s
    end

    def trace!(datum, trace_id)
      method = datum[:method].to_s
      url_string = Excon::Utils::request_uri(datum)
      url = URI(url_string)
      service_name = service_name(datum, url.host)

      span = Trace.tracer.start_span(trace_id, method.downcase)
      # annotate with method (GET/POST/etc.) and uri path
      span.kind = Trace::Span::Kind::CLIENT
      span.remote_endpoint = remote_endpoint(url, service_name)
      span.record_tag(Trace::Span::Tag::METHOD, method.upcase)
      span.record_tag(Trace::Span::Tag::PATH, url.path)

      # store the span in the datum hash so it can be used in the response_call
      datum[:span] = span
    rescue ArgumentError, URI::Error => e
      # Ignore URI errors, don't trace if there is no URI
    end
  end
end
