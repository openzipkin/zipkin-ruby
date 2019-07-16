require 'json'
require 'sucker_punch'
require 'zipkin-tracer/zipkin_sender_base'
require 'zipkin-tracer/hostname_resolver'

module Trace
  class RabbitMqPublisher
    include SuckerPunch::Job

    def perform(exchange, routing_key, spans)
      spans_with_ips = ::ZipkinTracer::HostnameResolver.new
        .spans_with_ips(spans, ZipkinRabbitMqSender::IP_FORMAT)
        .map(&:to_h)

      message = JSON.generate(spans_with_ips)

      exchange.publish(message, routing_key: routing_key)
    rescue => e
      SuckerPunch.logger.error(e)
    end
  end

  # This class sends information to the Zipkin RabbitMQ Collector.
  class ZipkinRabbitMqSender < ZipkinSenderBase
    IP_FORMAT = :string
    DEFAULT_EXCHANGE = ''
    DEAFULT_ROUTING_KEY = 'zipkin'

    def initialize(options)
      connection = options[:rabbit_mq_connection]
      channel = connection.create_channel
      exchange_name = options[:rabbit_mq_exchange] || DEFAULT_EXCHANGE
      @routing_key = options[:rabbit_mq_routing_key] || DEAFULT_ROUTING_KEY
      @exchange = channel.exchange(exchange_name)
      @async = options[:async] != false
      SuckerPunch.logger = options[:logger]

      super(options)
    end

    def flush!
      if @async
        RabbitMqPublisher.perform_async(@exchange, @routing_key, spans.dup)
      else
        RabbitMqPublisher.new.perform(@exchange, @routing_key, spans)
      end
    end
  end
end
