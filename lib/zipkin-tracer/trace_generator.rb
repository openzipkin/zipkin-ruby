module ZipkinTracer
  # This class generates trace ids.
  class TraceGenerator
    # Next id, based on the current information in the container
    def next_trace_id
      if TraceContainer.tracing_information_set?
        TraceContainer.current.next_id
      else
        generate_trace_id
      end
    end

    def generate_trace_id
      span_id = generate_id
      Trace::TraceId.new(span_id, nil, span_id, should_sample?.to_s, Trace::Flags::EMPTY)
    end

    def should_sample?
      rand < (Trace.sample_rate || DEFAULT_SAMPLE_RATE)
    end

    private

    def generate_id
      rand(TRACE_ID_UPPER_BOUND)
    end

    TRACE_ID_UPPER_BOUND = 2**64
    DEFAULT_SAMPLE_RATE = 0.001
  end
end
