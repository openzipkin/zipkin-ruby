module Trace
  # Monkey patching Nulltracer from thrift.
  # All our tracers have a start_span method, adding it to
  # the NullTracer also.
  class NullTracer
    def with_new_span(trace_id, name)
      span = start_span(trace_id, name)
      result = yield span
      end_span(span)
      result
    end

    def start_span(trace_id, name)
      # NOOP
      Span.new(name, trace_id)
    end

    def end_span(span)
      # NOOP
    end

    def flush!
      # NOOP
    end
  end
end
