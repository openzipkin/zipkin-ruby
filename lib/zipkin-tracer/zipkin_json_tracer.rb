require 'json'
require 'sucker_punch'
require 'zipkin-tracer/zipkin_tracer_base'

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
  # This class sends information to the Zipkin API.
  # The API accepts a JSON representation of a list of spans
  class ZipkinJsonTracer < ZipkinTracerBase

    def initialize(options)
      SuckerPunch.logger = options[:logger]
      @json_api_host = options[:json_api_host]
      super(options)
    end

    def flush!
      AsyncJsonApiClient.new.async.perform(@json_api_host, spans.values.dup)
    end
  end
end
