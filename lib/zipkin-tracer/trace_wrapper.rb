module ZipkinTracer
  class TraceWrapper
    def self.wrap_in_custom_span(config, span_name, span_kind: Trace::Span::Kind::SERVER, app: nil)
      raise ArgumentError, "you must provide a block" unless block_given?

      zipkin_config = ZipkinTracer::Config.new(app, config).freeze
      tracer = ZipkinTracer::TracerFactory.new.tracer(zipkin_config)
      trace_id = ZipkinTracer::TraceGenerator.new.next_trace_id

      ZipkinTracer::TraceContainer.with_trace_id(trace_id) do
        tracer.with_new_span(trace_id, span_name) do |span|
          span.kind = span_kind
          yield
        end
      end
    end
  end
end
