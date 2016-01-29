module ZipkinTracer
  class TraceClient
    LOCAL_COMPONENT = 'lc'.freeze
    STRING_TYPE = 'STRING'.freeze

    def self.local_component_span(&block)
      self.new(LOCAL_COMPONENT, &block) if block_given?
    end

    def initialize(name, &block)
      Trace.tracer.with_new_span(Trace.id, name) do |span|
        @span = span
        block.call(self)
      end
    end

    def record(key)
      @span.record(Trace::Annotation.new(key, Trace.default_endpoint))
    end

    def record_tag(key, value)
      @span.record(Trace::BinaryAnnotation.new(key, value, STRING_TYPE, Trace.default_endpoint))
    end

    def record_local_component(value)
      record_tag(LOCAL_COMPONENT, value)
    end

  end
end
