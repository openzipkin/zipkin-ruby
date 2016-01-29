module ZipkinTracer
  class TraceClient
    LOCAL_COMPONENT = 'lc'.freeze
    STRING_TYPE = 'STRING'.freeze

    def self.local_component_span(local_component_value, &block)
      if block_given?
        client = self.new(LOCAL_COMPONENT, &block)
        client.record_local_component local_component_value
      end
    end

    def initialize(name, &block)
      @trace_id = Trace.id.next_id
      Trace.tracer.with_new_span(@trace_id, name) do |span|
        @span = span
        block.call(self)
      end
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
