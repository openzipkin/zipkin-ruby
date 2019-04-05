module ZipkinTracer
  class TracerFactory
    def tracer(config)
      adapter = config.adapter

      tracer = case adapter
        when :json
          require 'zipkin-tracer/zipkin_json_tracer'
          options = { json_api_host: config.json_api_host, logger: config.logger }
          Trace::ZipkinJsonTracer.new(options)
        when :kafka
          require 'zipkin-tracer/zipkin_kafka_tracer'
          Trace::ZipkinKafkaTracer.new(zookeepers: config.zookeeper)
        when :kafka_producer
          require 'zipkin-tracer/zipkin_kafka_tracer'
          options = { producer: config.kafka_producer }
          options[:topic] = config.kafka_topic unless config.kafka_topic.nil?
          Trace::ZipkinKafkaTracer.new(options)
        when :sqs
          require 'zipkin-tracer/zipkin_sqs_tracer'
          options = { logger: config.logger, queue_name: config.sqs_queue_name , region: config.sqs_region }
          Trace::ZipkinSqsTracer.new(options)
        when :logger
          require 'zipkin-tracer/zipkin_logger_tracer'
          Trace::ZipkinLoggerTracer.new(logger: config.logger)
        else
          require 'zipkin-tracer/zipkin_null_tracer'
          Trace::NullTracer.new
      end
      Trace.tracer = tracer

      tracer
    end
  end
end
