module ZipkinTracer
  class TraceWrapper
    def self.wrap_in_custom_span(config, span_name, span_kind: Trace::Span::Kind::SERVER, app: nil)
      raise ArgumentError, "you must provide a block" unless block_given?

      initialize_tracer(app, config)
      trace_id = ZipkinTracer::TraceGenerator.new.next_trace_id

      ZipkinTracer::TraceContainer.with_trace_id(trace_id) do
        if trace_id.sampled?
          Trace.tracer.with_new_span(trace_id, span_name) do |span|
            span.kind = span_kind
            yield(span)
          end
        else
          yield(ZipkinTracer::NullSpan.new)
        end
      end
    end

    def self.initialize_tracer(app, config)
      return if Trace.tracer

      zipkin_config = ZipkinTracer::Config.new(app, config).freeze
      ZipkinTracer::TracerFactory.new.tracer(zipkin_config)
    end
  end
end
