require 'zipkin-tracer/zipkin_tracer_base'
require 'zipkin-tracer/careless_scribe'
require 'zipkin-tracer/hostname_resolver'


module Trace
  class ScribeTracer < ZipkinTracerBase
    TRACER_CATEGORY = "zipkin".freeze

    def initialize(options)
      @scribe = CarelessScribe.new(options[:scribe_server])
      super(options)
    end

    def flush!
      resolved_spans = ::ZipkinTracer::HostnameResolver.new.spans_with_ips(spans)
      @scribe.batch do
        messages = resolved_spans.map do |span|
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
