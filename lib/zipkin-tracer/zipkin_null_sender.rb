module Trace
  class NullSender
    def with_new_span(trace_id, name, tags = {})
      span = start_span(trace_id, name, tags)
      result = yield span
      end_span(span)
      result
    end

    def start_span(trace_id, name, tags = {})
      Span.new(name, trace_id, tags)
    end

    def end_span(span)
      span.close if span.respond_to?(:close)
    end

    def flush!
      # NOOP
    end
  end
end
