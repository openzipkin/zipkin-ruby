require 'zipkin-tracer/zipkin_tracer_base'

module Trace
  class ZipkinLoggerTracer < ZipkinTracerBase

    def initialize(options)
      @logger = options[:logger]
      super(options)
    end

    def flush!
      @logger.info("ZIPKIN SPANS: #{spans.map(&:to_h)}")
    end
  end
end
