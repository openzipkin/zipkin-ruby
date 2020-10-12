require 'faraday'

module Trace
  # This class is a base for senders sending information to Zipkin.
  # It knows about zipkin types of annotations and send traces when the server
  # is done with its request
  # Senders dealing with zipkin should inherit from this class and implement the
  # flush! method which actually sends the information
  class ZipkinSenderBase
    def initialize(options = {})
      @options = options
      reset
    end

    def with_new_span(trace_id, name)
      span = start_span(trace_id, name)
      result = yield span
      end_span(span)
      result
    end

    def end_span(span, timestamp = Time.now)
      span.close(timestamp)
      # If in a thread not handling incoming http requests, it will not have Kind::SERVER, so the span
      # will never be flushed and will cause memory leak.
      # If no parent span, then current span needs to flush when it ends.
      return if skip_flush?(span)

      flush!
      reset
    end

    def start_span(trace_id, name, timestamp = Time.now)
      span = Span.new(name, trace_id, timestamp)
      span.local_endpoint = Trace.default_endpoint
      store_span(trace_id, span)
      span
    end

    def skip_flush?(span)
      return false if span.kind == Trace::Span::Kind::SERVER || span.kind == Trace::Span::Kind::CONSUMER

      spans.any? { |s| s.kind == Trace::Span::Kind::SERVER || s.kind == Trace::Span::Kind::CONSUMER }
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
