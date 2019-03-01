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
        when :logger
          require 'zipkin-tracer/zipkin_logger_tracer'
          Trace::ZipkinLoggerTracer.new(logger: config.logger)
        else
          require 'zipkin-tracer/zipkin_null_tracer'
          Trace::NullTracer.new
      end
      Trace.tracer = tracer

      # TODO: move this to the TracerBase and kill scribe tracer
      ip_format = [:kafka, :kafka_producer].include?(config.adapter) ? :i32 : :string
      Trace.default_endpoint = Trace::Endpoint.local_endpoint(
        service_name(config.service_name),
        ip_format
      )
      tracer
    end

    # Use the Domain environment variable to extract the service name, otherwise use the default config name
    # TODO: move to the config object
    def service_name(default_name)
      ENV["DOMAIN"].to_s.empty? ? default_name : ENV["DOMAIN"].split('.').first
    end
  end
end
