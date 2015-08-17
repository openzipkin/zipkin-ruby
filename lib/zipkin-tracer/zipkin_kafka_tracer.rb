require 'finagle-thrift'
require 'finagle-thrift/tracer'
require 'hermann/producer'
require 'hermann/discovery/zookeeper'

module Trace
  class ZipkinKafkaTracer < Tracer
    TRACER_CATEGORY     = "zipkin".freeze
    DEFAULT_KAFKA_TOPIC = "zipkin_kafka".freeze

    def initialize(opts={})
      @logger = opts[:logger]
      @topic  = opts[:topic] || DEFAULT_KAFKA_TOPIC
      reset
    end

    # need to connect after initialization
    def connect(zookeepers)
      broker_ids = Hermann::Discovery::Zookeeper.new(zookeepers).get_brokers
      @producer  = Hermann::Producer.new(nil, broker_ids)
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

      flush!
    end

    def set_rpc_name(id, name)
      return unless id.sampled?
      span = get_span_for_id(id)
      span.name = name.to_s
    end

    private
      def reset
        @spans = {}
      end

      def get_span_for_id(id)
        key = id.span_id.to_s
        @spans[key] ||= begin
          Span.new("", id)
        end
      end

      def flush!
        messages = @spans.values.map do |span|
          buf = ''
          trans = Thrift::MemoryBufferTransport.new(buf)
          oprot = Thrift::BinaryProtocol.new(trans)
          span.to_thrift.write(oprot)
          @producer.push(buf, :topic => @topic).value!
        end
      end
  end
end