module ZipkinTracer
  class TraceClient
    LOCAL_COMPONENT = 'lc'.freeze
    STRING_TYPE = 'STRING'.freeze

    def self.record(key)
      Trace.record(Trace::Annotation.new(key, Trace.default_endpoint))
    end

    def self.record_tag(key, value)
      Trace.record(Trace::BinaryAnnotation.new(key, value, STRING_TYPE, Trace.default_endpoint))
    end

    def self.record_local_component(value)
      record_tag(LOCAL_COMPONENT, value)
    end

    def self.trace(key = nil)
      if block_given?
        record "Start: #{key}"
        yield self
        record "End: #{key}"
      end
    end
  end
end
