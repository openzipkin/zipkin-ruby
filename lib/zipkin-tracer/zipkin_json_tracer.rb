require 'json'
require 'sucker_punch'
require 'zipkin-tracer/zipkin_tracer_base'
require 'zipkin-tracer/hostname_resolver'

class AsyncJsonApiClient
  include SuckerPunch::Job
  SPANS_PATH = '/api/v2/spans'

  def perform(json_api_host, spans)
    spans_with_ips = ::ZipkinTracer::HostnameResolver.new.spans_with_ips(spans).map(&:to_h)
    resp = Faraday.new(json_api_host).post do |req|
      req.url SPANS_PATH
      req.headers['Content-Type'] = 'application/json'
      req.body = JSON.generate(spans_with_ips)
    end
  rescue Net::ReadTimeout, Faraday::ConnectionFailed => e
    error_message = "Error while connecting to #{json_api_host}: #{e.class.inspect} with message '#{e.message}'. " \
                    "Please make sure the URL / port are properly specified for the Zipkin server."
    SuckerPunch.logger.error(error_message)
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
      AsyncJsonApiClient.perform_async(@json_api_host, spans.dup)
    end
  end
end
