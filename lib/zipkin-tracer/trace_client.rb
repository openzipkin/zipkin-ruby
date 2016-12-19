module ZipkinTracer
  class NullSpan
    def method_missing(name, *args)
    end
  end

  # The trace client provides the user of this library an API to interact
  # with tracing information.
  class TraceClient
    def self.local_component_span(local_component_value, &block)
      new.trace(local_component_value, &block)
    end

    def trace(local_component_value, &block)
      raise ArgumentError, "no block given" unless block
      @trace_id = TraceGenerator.new.next_trace_id
      result = nil
      if @trace_id.sampled?
        TraceContainer.with_trace_id(@trace_id) do
          Trace.tracer.with_new_span(@trace_id, local_component_value) do |span|
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
