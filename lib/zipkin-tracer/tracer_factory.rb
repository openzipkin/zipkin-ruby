module ZipkinTracer
  class TracerFactory
    def tracer(config)
      adapter = config.adapter

      tracer = case adapter
        when :json
          require 'zipkin-tracer/zipkin_http_sender'
          options = {
            async: config.async,
            json_api_host: config.json_api_host,
            logger: config.logger
          }
          Trace::ZipkinHttpSender.new(options)
        when :kafka
          require 'zipkin-tracer/zipkin_kafka_sender'
          Trace::ZipkinKafkaSender.new(zookeepers: config.zookeeper)
        when :kafka_producer
          require 'zipkin-tracer/zipkin_kafka_sender'
          options = { producer: config.kafka_producer }
          options[:topic] = config.kafka_topic unless config.kafka_topic.nil?
          Trace::ZipkinKafkaSender.new(options)
        when :sqs
          require 'zipkin-tracer/zipkin_sqs_sender'
          options = {
            async: config.async,
            logger: config.logger,
            queue_name: config.sqs_queue_name,
            region: config.sqs_region
          }
          Trace::ZipkinSqsSender.new(options)
        when :rabbit_mq
          require 'zipkin-tracer/zipkin_rabbit_mq_sender'
          options = {
            rabbit_mq_connection: config.rabbit_mq_connection,
            rabbit_mq_exchange: config.rabbit_mq_exchange,
            rabbit_mq_routing_key: config.rabbit_mq_routing_key,
            async: config.async,
            logger: config.logger
          }
          Trace::ZipkinRabbitMqSender.new(options)
        when :logger
          require 'zipkin-tracer/zipkin_logger_sender'
          Trace::ZipkinLoggerSender.new(logger: config.logger)
        else
          require 'zipkin-tracer/zipkin_null_sender'
          Trace::NullSender.new
      end
      Trace.tracer = tracer

      tracer
    end
  end
end
