module Trace
  # Monkey patching Nulltracer from thrift.
  # All our tracers have a start_span method, adding it to
  # the NullTracer also.
  class NullTracer
    def with_new_span(trace_id, name)
      span = Span.new(name, trace_id)
      yield span
    end
  end
end
