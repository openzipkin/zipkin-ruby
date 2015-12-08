require 'json'
require 'faraday'
require 'finagle-thrift'
require 'finagle-thrift/tracer'

class AsyncJsonApiClient
  include SuckerPunch::Job
  SPANS_PATH = '/api/v1/spans'

  def perform(json_api_host, spans)
    resp = Faraday.new(json_api_host).post do |req|
      req.url SPANS_PATH
      req.headers['Content-Type'] = 'application/json'
      req.body = JSON.generate(spans.map!(&:to_h))
    end
  rescue => e
    SuckerPunch.logger.error(e)
  end
end

module Trace
  class ZipkinJsonTracer < Tracer
    TRACER_CATEGORY = "zipkin".freeze

    def initialize(json_api_host, traces_buffer)
      @json_api_host = json_api_host
      @traces_buffer = traces_buffer
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
      end
    end

    def set_rpc_name(id, name)
      return unless id.sampled?
      span = get_span_for_id(id)
      span.name = name.to_s
    end

    private

    def get_span_for_id(id)
      key = id.span_id.to_s
      @spans[key] ||= begin
        Span.new("", id)
      end
    end

    def reset
      @count = 0
      @spans = {}
    end

    def flush!
      AsyncJsonApiClient.new.async.perform(@json_api_host, @spans.values.dup)
      reset
    end
  end
end
