require 'faraday'
require 'finagle-thrift/tracer'

module Trace
  # This class is a base for tracers sending information to Zipkin.
  # It knows about zipkin types of annotations and send traces when the server
  # is done with its request
  # Traces dealing with zipkin should inherit from this class and implement the
  # flush! method which actually sends the information
  class ZipkinTracerBase < Tracer

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
      # if in a thread not handling incoming http requests, it will not have Annotation::SERVER_SEND, so the span
      # will never be flushed and will cause memory leak.
      # It will have CLIENT_SEND and CLIENT_RECV if the thread sends out http requests, so use CLIENT_RECV as the sign
      # to flush the span.
      has_server_recv_span = spans.any? do |s|
        s.annotations.any? { |ann| ann.value == Annotation::SERVER_RECV }
      end
      if span.annotations.any? { |ann| ann.value == Annotation::SERVER_SEND } ||
          (!has_server_recv_span &&
              span.annotations.any? { |ann| ann.value == Annotation::CLIENT_RECV })
        flush!
        reset
      end
    end

    def start_span(trace_id, name)
      span = Span.new(name, trace_id)
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
