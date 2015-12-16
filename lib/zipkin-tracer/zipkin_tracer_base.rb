require 'faraday'
require 'finagle-thrift'
require 'finagle-thrift/tracer'

module Trace
  # This class is a base for tracers sending information to Zipkin.
  # It knows about zipkin types of annotations and send traces when the server
  # is done with its request
  # Traces dealing with zipkin should inherit from this class and implement the
  # flush! method which actually sends the information
  class ZipkinTracerBase < Tracer
    TRACER_CATEGORY = "zipkin".freeze

    def initialize(options={})
      @traces_buffer = options[:traces_buffer] || raise(ArgumentError, 'A proper buffer must be setup for the Zipkin tracer')
      @options = options
      reset
    end

    def record(id, annotation)
      return unless id.sampled?
      span = get_span_for_id(id)

      case annotation
      when BinaryAnnotation
        span.binary_annotations << annotation
      when Annotation
        span.annotations << annotation
      end

      @count += 1
      if @count >= @traces_buffer || (annotation.is_a?(Annotation) && annotation.value == Annotation::SERVER_SEND)
        flush!
        reset
      end
    end

    def set_rpc_name(id, name)
      return unless id.sampled?
      span = get_span_for_id(id)
      span.name = name.to_s
    end

    def flush!
      raise "not implemented"
    end

    private

    def get_span_for_id(id)
      key = id.span_id.to_s
      @spans[key] ||= Span.new("", id)
    end

    def reset
      @count = 0
      @spans = {}
    end
  end
end
