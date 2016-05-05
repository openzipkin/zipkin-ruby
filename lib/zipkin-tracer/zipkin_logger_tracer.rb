require 'zipkin-tracer/zipkin_tracer_base'
require 'zipkin-tracer/hostname_resolver'
require 'json'

module Trace
  class ZipkinLoggerTracer < ZipkinTracerBase
    TRACING_KEY = 'Tracing information'

    def initialize(options)
      @logger = options[:logger]
      @logger_accepts_data = @logger.respond_to?(:info_with_data)
      super(options)
    end

    def flush!
      formatted_spans = ::ZipkinTracer::HostnameResolver.new.spans_with_ips(spans).map(&:to_h)
      if @logger_accepts_data
        @logger.info_with_data(TRACING_KEY, formatted_spans)
      else
        @logger.info({ TRACING_KEY => formatted_spans }.to_json)
      end
    end
  end
end
