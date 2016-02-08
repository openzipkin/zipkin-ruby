module ZipkinTracer
  class NullSpan
    def method_missing(name, *args)
    end
  end

  class TraceClient
    def self.local_component_span(local_component_value, &block)
      client = self.new
      client.trace(local_component_value, &block)
    end

    def trace(local_component_value, &block)
      raise ArgumentError, "no block given" unless block

      @trace_id = Trace.id.next_id
      result = nil
      if @trace_id.sampled?
        Trace.with_trace_id(@trace_id) do
          Trace.tracer.with_new_span(@trace_id, Trace::BinaryAnnotation::LOCAL_COMPONENT) do |span|
            result = block.call(span)
            span.record_local_component local_component_value
          end
        end
      else
        result = block.call(NullSpan.new)
      end
      result
    end

  end
end
