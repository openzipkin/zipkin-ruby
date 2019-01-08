# IF hermann isn't present, we might be providing another kafka producer
begin
  require 'hermann/producer'
  require 'hermann/discovery/zookeeper'
  require 'finagle-thrift'
rescue LoadError => e
end

require 'zipkin-tracer/zipkin_tracer_base'
require 'zipkin-tracer/hostname_resolver'

module Trace
  # This class sends information to Zipkin through Kafka.
  # Spans are encoded using Thrift
  class ZipkinKafkaTracer < ZipkinTracerBase
    DEFAULT_KAFKA_TOPIC = "zipkin".freeze

    def initialize(options = {})
      @topic  = options[:topic] || DEFAULT_KAFKA_TOPIC

      if options[:producer] && options[:producer].respond_to?(:push)
        @producer = options[:producer]
      elsif options[:zookeepers]
        initialize_hermann_producer(options[:zookeepers])
      else
        raise ArgumentError, "No (kafka) :producer option (accepting #push) and no :zookeeper option provided."
      end
      super(options)
    end

    def flush!
      resolved_spans = ::ZipkinTracer::HostnameResolver.new.spans_with_ips(spans)
      resolved_spans.each do |span|
        buf = ''
        trans = Thrift::MemoryBufferTransport.new(buf)
        oprot = Thrift::BinaryProtocol.new(trans)
        span.to_thrift.write(oprot)
        retval = @producer.push(buf, topic: @topic)

        # If @producer#push returns a promise/promise-like object, block until it
        # resolves
        retval.value! if retval.respond_to?(:value!)

        retval
      end
    rescue Exception
      # Ignore socket errors, etc
    end

    private
    def initialize_hermann_producer(zookeepers)
      broker_ids = Hermann::Discovery::Zookeeper.new(zookeepers).get_brokers
      @producer  = Hermann::Producer.new(nil, broker_ids)
    end
  end
end
