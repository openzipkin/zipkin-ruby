require 'uri'

module ZipkinTracer
  class NetHttpHandler
    def initialize(app, endpoint = nil)
      @app = app
      @endpoint = endpoint
    end

    def call(request, body = nil)
      trace_id = TraceGenerator.new.next_trace_id

      TraceContainer.with_trace_id(trace_id) do
        b3_headers.each do |method, header|
          request.add_field(header, trace_id.send(method).to_s)
        end
        if Trace.tracer && trace_id.sampled?
          trace!(request, body, trace_id)
        else
          @app.call(request, body)
        end
      end
    end

    private

    def b3_headers
      {
        trace_id: 'X-B3-TraceId',
        parent_id: 'X-B3-ParentSpanId',
        span_id: 'X-B3-SpanId',
        sampled: 'X-B3-Sampled',
        flags: 'X-B3-Flags'
      }
    end

    def trace!(request, body, trace_id)
      response = nil
      method = request.method
      url = @endpoint.respond_to?(:host) ? @endpoint : URI.parse(@endpoint.to_s)
      host = url.host
      path = url.path
      remote_endpoint = Trace::Endpoint.remote_endpoint(url, host) # The endpoint we are calling.
      span_name = "#{method.downcase} #{path}"

      Trace.tracer.with_new_span(trace_id, span_name) do |span|
        @span = span # So we can record on exceptions
        # annotate with method (GET/POST/etc.) and uri path
        span.kind = Trace::Span::Kind::CLIENT
        span.remote_endpoint = remote_endpoint
        span.local_endpoint = remote_endpoint
        span.record_tag(Trace::Span::Tag::METHOD, method.upcase)
        span.record_tag(Trace::Span::Tag::PATH, path)

        response = @app.call(request, body)

        span.record_status(response.code)
        response
      end

      response
    rescue StandardError => e
      record_error(@span, e.message)
      raise e
    end

    def record_error(span, msg)
      span.record_tag(Trace::Span::Tag::ERROR, msg)
    end
  end
end
