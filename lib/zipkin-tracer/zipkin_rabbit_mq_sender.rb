require 'json'
require 'zipkin-tracer/zipkin_sender_base'
require 'zipkin-tracer/hostname_resolver'

module Trace
  class RabbitMqPublisher
    def initialize(connection, exchange, routing_key)
      @connection = connection
      channel = @connection.create_channel
      @exchange = channel.exchange(exchange)
      @routing_key = routing_key
    end

    def publish(message)
      @exchange.publish(message, routing_key: @routing_key)
    end
  end

  # This class sends information to the Zipkin RabbitMQ Collector.
  class ZipkinRabbitMqSender < ZipkinSenderBase
    IP_FORMAT = :string
    DEFAULT_EXCHANGE = ''
    DEAFULT_ROUTING_KEY = 'zipkin'

    def initialize(options)
      connection = options[:rabbit_mq_connection]
      exchange = options[:rabbit_mq_exchange] || DEFAULT_EXCHANGE
      routing_key = options[:rabbit_mq_routing_key] || DEAFULT_ROUTING_KEY
      @publisher = RabbitMqPublisher.new(connection, exchange, routing_key)

      super(options)
    end

    def flush!
      spans_with_ips = ::ZipkinTracer::HostnameResolver.new
        .spans_with_ips(spans, ZipkinRabbitMqSender::IP_FORMAT)
        .map(&:to_h)

      message = JSON.generate(spans_with_ips)

      @publisher.publish(message)
    end
  end
end
