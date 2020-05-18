module ZipkinTracer
  class TraceWrapper
    REQUIRED_KEYS = %i[trace_id span_id].freeze
    KEYS = %i[trace_id parent_id span_id sampled flags].freeze

    def self.wrap_in_custom_span(config, span_name, span_kind: Trace::Span::Kind::SERVER, app: nil, trace_context: nil)
      raise ArgumentError, "you must provide a block" unless block_given?

      initialize_tracer(app, config)
      trace_id = next_trace_id(trace_context)

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

    def self.next_trace_id(trace_context)
      if trace_context.is_a?(Hash) && REQUIRED_KEYS.all? { |key| trace_context.key?(key) }
        trace_context[:flags] = (trace_context[:flags] || Trace::Flags::EMPTY).to_i
        Trace::TraceId.new(*trace_context.values_at(*KEYS)).next_id
      else
        ZipkinTracer::TraceGenerator.new.next_trace_id
      end
    end
  end
end
