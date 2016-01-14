require 'hermann/producer'
require 'hermann/discovery/zookeeper'
require 'zipkin-tracer/zipkin_tracer_base'

module Trace
  # This class sends information to Zipkin through Kafka.
  # Spans are encoded using Thrift
  class ZipkinKafkaTracer < ZipkinTracerBase
    DEFAULT_KAFKA_TOPIC = "zipkin_kafka".freeze

    def initialize(options = {})
      @topic  = options[:topic] || DEFAULT_KAFKA_TOPIC
      broker_ids = Hermann::Discovery::Zookeeper.new(options[:zookeepers]).get_brokers
      @producer  = Hermann::Producer.new(nil, broker_ids)
      options[:traces_buffer] ||= 1  # Default in Kafka is sending as soon as possible. No buffer.
      super(options)
    end

    def flush!
      messages = spans.values.map do |span|
        buf = ''
        trans = Thrift::MemoryBufferTransport.new(buf)
        oprot = Thrift::BinaryProtocol.new(trans)
        span.to_thrift.write(oprot)
        @producer.push(buf, topic: @topic).value!
      end
    rescue Exception
      # Ignore socket errors, etc
    end
  end
end
