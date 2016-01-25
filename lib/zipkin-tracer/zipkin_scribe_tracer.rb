require 'zipkin-tracer/zipkin_tracer_base'
require 'zipkin-tracer/careless_scribe'

module Trace
  class ScribeTracer < ZipkinTracerBase
    TRACER_CATEGORY = "zipkin".freeze

    def initialize(options)
      @scribe = CarelessScribe.new(options[:scribe_server])
      super(options)
    end

    def flush!
      @scribe.batch do
        messages = spans.values.map do |span|
          buf = ''
          trans = Thrift::MemoryBufferTransport.new(buf)
          oprot = Thrift::BinaryProtocol.new(trans)
          span.to_thrift.write(oprot)
          Base64.encode64(buf).gsub("\n", "")
        end
        @scribe.log(messages, TRACER_CATEGORY)
      end
      reset
    end
  end
end
