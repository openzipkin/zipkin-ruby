module ZipkinTracer
  class TraceClient
    LOCAL_COMPONENT = 'lc'.freeze
    STRING_TYPE = 'STRING'.freeze

    def self.local_component_span(local_component_value, &block)
      client = self.new
      client.trace(local_component_value, &block)
    end

    def trace(local_component_value, &block)
      raise ArgumentError, "no block given" unless block

      @trace_id = Trace.id.next_id
      result = nil
      Trace.with_trace_id(@trace_id) do
        Trace.tracer.with_new_span(@trace_id, LOCAL_COMPONENT) do |span|
          @span = span
          result = block.call(self)
          record_local_component local_component_value
        end
      end
      result
    end

    def record(key)
      @span.record(Trace::Annotation.new(key, Trace.default_endpoint)) if @trace_id.sampled?
    end

    def record_tag(key, value)
      @span.record(Trace::BinaryAnnotation.new(key, value, STRING_TYPE, Trace.default_endpoint)) if @trace_id.sampled?
    end

    def record_local_component(value)
      record_tag(LOCAL_COMPONENT, value)
    end

  end
end
