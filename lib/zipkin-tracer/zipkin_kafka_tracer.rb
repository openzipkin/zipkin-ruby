require 'finagle-thrift'
require 'finagle-thrift/tracer'
require 'hermann/producer'
require 'hermann/discovery/zookeeper'
require 'zipkin-tracer/zipkin_tracer_base'

module Trace
  class ZipkinKafkaTracer < ZipkinTracerBase
    DEFAULT_KAFKA_TOPIC = "zipkin_kafka".freeze

    # need to connect after initialization
    def connect(zookeepers)
      broker_ids = Hermann::Discovery::Zookeeper.new(zookeepers).get_brokers
      @producer  = Hermann::Producer.new(nil, broker_ids)
    end

    def flush!
      topic = opts[:topic] || DEFAULT_KAFKA_TOPIC
      messages = @spans.values.map do |span|
        buf = ''
        trans = Thrift::MemoryBufferTransport.new(buf)
        oprot = Thrift::BinaryProtocol.new(trans)
        span.to_thrift.write(oprot)
        @producer.push(buf, :topic => topic).value!
      end
    end
  end
end