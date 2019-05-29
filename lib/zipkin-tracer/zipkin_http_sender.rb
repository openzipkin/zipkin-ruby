require 'json'
require 'sucker_punch'
require 'zipkin-tracer/zipkin_sender_base'
require 'zipkin-tracer/hostname_resolver'

module Trace
  class HttpApiClient
    include SuckerPunch::Job
    SPANS_PATH = '/api/v2/spans'

    def perform(json_api_host, spans)
      spans_with_ips =
        ::ZipkinTracer::HostnameResolver.new.spans_with_ips(spans, ZipkinHttpSender::IP_FORMAT).map(&:to_h)

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

  # This class sends information to the Zipkin API.
  # The API accepts a JSON representation of a list of spans
  class ZipkinHttpSender < ZipkinSenderBase
    IP_FORMAT = :string

    def initialize(options)
      @json_api_host = options[:json_api_host]
      @async = options[:async] != false
      SuckerPunch.logger = options[:logger]
      super(options)
    end

    def flush!
      if @async
        HttpApiClient.perform_async(@json_api_host, spans.dup)
      else
        HttpApiClient.new.perform(@json_api_host, spans)
      end
    end
  end
end
