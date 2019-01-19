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

    def current
      if TraceContainer.tracing_information_set?
        TraceContainer.current
      else
        generate_trace_id
      end
    end

    def generate_trace_id
      span_id = generate_id
      Trace::TraceId.new(generate_id_from_span_id(span_id), nil, span_id, should_sample?.to_s, Trace::Flags::EMPTY)
    end

    def should_sample?
      rand < (Trace.sample_rate || DEFAULT_SAMPLE_RATE)
    end

    def generate_id_from_span_id(span_id)
      Trace.trace_id_128bit ? generate_id_128bit(span_id) : span_id
    end

    def generate_id
      rand(TRACE_ID_UPPER_BOUND)
    end

    private

    def generate_id_128bit(span_id)
      trace_id_low_64bit = '%016x' % span_id
      "#{trace_id_epoch_seconds}#{trace_id_high_32bit}#{trace_id_low_64bit}".hex
    end

    def trace_id_epoch_seconds
      '%08x' % Time.now.to_i
    end

    def trace_id_high_32bit
      '%08x' % rand(TRACE_ID_HIGH_32BIT_UPPER_BOUND)
    end

    TRACE_ID_UPPER_BOUND = 2**64
    TRACE_ID_HIGH_32BIT_UPPER_BOUND = 2**32
    DEFAULT_SAMPLE_RATE = 0.001
  end
end
