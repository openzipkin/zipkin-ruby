require 'logger'
require 'zipkin-tracer/application'
require 'zipkin-tracer/rack/zipkin-tracer'

module ZipkinTracer
  # Configuration of this gem. It reads the configuration and provides default values
  class Config
    attr_reader :service_name, :sample_rate, :sampled_as_boolean, :check_routes, :trace_id_128bit, :async, :logger,
      :json_api_host, :zookeeper, :kafka_producer, :kafka_topic, :sqs_queue_name, :sqs_region, :log_tracing,
      :annotate_plugin, :filter_plugin, :whitelist_plugin, :rabbit_mq_connection, :rabbit_mq_exchange,
      :rabbit_mq_routing_key, :write_b3_single_format, :supports_join

    def initialize(app, config_hash)
      config = config_hash || Application.config(app)
      # The name of the current service
      @service_name      = config[:service_name]
      # The address of the Zipkin server which we will send traces to
      @json_api_host     = config[:json_api_host]
      # Zookeeper information
      @zookeeper         = config[:zookeeper]
      # Kafka producer information
      @kafka_producer    = config[:producer]
      @kafka_topic       = config[:topic] if present?(config[:topic])
      # Amazon SQS queue information
      @sqs_queue_name    = config[:sqs_queue_name]
      @sqs_region        = config[:sqs_region]
      # Rabbit MQ information
      @rabbit_mq_connection   = config[:rabbit_mq_connection]
      @rabbit_mq_exchange     = config[:rabbit_mq_exchange]
      @rabbit_mq_routing_key  = config[:rabbit_mq_routing_key]
      # Percentage of traces which by default this service traces (as float, 1.0 means 100%)
      @sample_rate       = config[:sample_rate] || DEFAULTS[:sample_rate]
      # A block of code which can be called to do extra annotations of traces
      @annotate_plugin   = config[:annotate_plugin]   # call for trace annotation
      # A block of code which can be called to skip traces. Skip tracing if returns false
      @filter_plugin     = config[:filter_plugin]
      # A block of code which can be called to force sampling. Forces sampling if returns true
      @whitelist_plugin  = config[:whitelist_plugin]
      # be strict about checking `false` to ensure misconfigurations don't lead to accidental synchronous configurations
      @async             = config[:async] != false
      @logger            = config[:logger] || Application.logger
      # Was the logger in fact setup by the client?
      @log_tracing       = config[:log_tracing]
      # When set to false, it uses 1/0 in the 'X-B3-Sampled' header, else uses true/false
      @sampled_as_boolean = config[:sampled_as_boolean].nil? ? DEFAULTS[:sampled_as_boolean] : config[:sampled_as_boolean]
      # The current default is true for compatibility but services are encouraged to move on.
      if @sampled_as_boolean
        @logger && @logger.warn("Using a boolean in the Sampled header is deprecated. Consider setting sampled_as_boolean to false")
      end
      # When set to true, only routable requests are sampled
      @check_routes      = config[:check_routes].nil? ? DEFAULTS[:check_routes] : config[:check_routes]

      # When set to true, high 8-bytes will be prepended to trace_id.
      # The upper 4-bytes are epoch seconds and the lower 4-bytes are random.
      # This makes it convertible to Amazon X-Ray trace ID format v1.
      # (See http://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-request-tracing.html)
      @trace_id_128bit = config[:trace_id_128bit].nil? ? DEFAULTS[:trace_id_128bit] : config[:trace_id_128bit]
      # When set to true, only writes a single b3 header for outbound propagation.
      @write_b3_single_format =
        config[:write_b3_single_format].nil? ? DEFAULTS[:write_b3_single_format] : config[:write_b3_single_format]
      # When set to false, the it will force client and server spans to have different spanId's. This is important
      # because zipkin traces may be reported to non-zipkin backends that might not support the concept of
      # joining spans.
      @supports_join = config[:supports_join].nil? ? DEFAULTS[:supports_join] : config[:supports_join]

      Trace.sample_rate = @sample_rate
      Trace.trace_id_128bit = @trace_id_128bit
      Trace.write_b3_single_format = @write_b3_single_format

      Trace.default_endpoint = Trace::Endpoint.local_endpoint(
        domain_service_name(@service_name)
      )
    end

    def adapter
      if present?(@json_api_host)
        :json
      elsif present?(@zookeeper) && RUBY_PLATFORM == 'java'
        :kafka
      elsif @kafka_producer && @kafka_producer.respond_to?(:push)
        :kafka_producer
      elsif present?(@sqs_queue_name) && defined?(Aws::SQS)
        :sqs
      elsif @rabbit_mq_connection
        :rabbit_mq
      elsif !!@log_tracing
        :logger
      else
        nil
      end
    end

    private

    # Use the Domain environment variable to extract the service name, otherwise use the default config name
    # TODO: move to the config object
    def domain_service_name(default_name)
      ENV["DOMAIN"].to_s.empty? ? default_name : ENV["DOMAIN"].split('.').first
    end

    DEFAULTS = {
      sample_rate: 0.1,
      sampled_as_boolean: true,
      check_routes: false,
      trace_id_128bit: false,
      write_b3_single_format: false,
      supports_join: true
    }

    def present?(str)
      return false if str.nil?
      !!(/\A[[:space:]]*\z/ !~ str)
    end
  end
end
