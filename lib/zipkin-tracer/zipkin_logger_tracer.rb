require 'zipkin-tracer/zipkin_tracer_base'
require 'zipkin-tracer/hostname_resolver'

module Trace
  class ZipkinLoggerTracer < ZipkinTracerBase

    def initialize(options)
      @logger = options[:logger]
      super(options)
    end

    def flush!
      formatted_spans = ::ZipkinTracer::HostnameResolver.new.spans_with_ips(spans).map(&:to_h)
      @logger.info "ZIPKIN SPANS: #{formatted_spans}"
    end
  end
end
