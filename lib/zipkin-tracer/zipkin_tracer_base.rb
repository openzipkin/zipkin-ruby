require 'faraday'

module Trace
  # This class is a base for tracers sending information to Zipkin.
  # It knows about zipkin types of annotations and send traces when the server
  # is done with its request
  # Traces dealing with zipkin should inherit from this class and implement the
  # flush! method which actually sends the information
  class ZipkinTracerBase

    def initialize(options={})
      @options = options
      reset
    end

    def with_new_span(trace_id, name)
      span = start_span(trace_id, name)
      result = yield span
      end_span(span)
      result
    end

    def end_span(span)
      span.close
      # If in a thread not handling incoming http requests, it will not have Kind::SERVER, so the span
      # will never be flushed and will cause memory leak.
      # If no parent span, then current span needs to flush when it ends.
      if !span.has_parent_span? || span.kind == Trace::Span::Kind::SERVER
        flush!
        reset
      end
    end

    def start_span(trace_id, name)
      span = Span.new(name, trace_id)
      span.local_endpoint = Trace.default_endpoint
      store_span(trace_id, span)
      span
    end

    def flush!
      raise "not implemented"
    end

    private

    THREAD_KEY = :zipkin_spans

    def spans
      Thread.current[THREAD_KEY] ||= []
    end

    def store_span(id, span)
      spans.push(span)
    end

    def reset
      Thread.current[THREAD_KEY] = []
    end

  end
end
