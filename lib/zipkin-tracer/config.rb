require 'logger'
require 'zipkin-tracer/application'
require 'zipkin-tracer/rack/zipkin-tracer'

module ZipkinTracer
  # Configuration of this gem. It reads the configuration and provides default values
  class Config
    attr_reader :service_name, :json_api_host,
      :zookeeper, :sample_rate, :logger, :log_tracing,
      :annotate_plugin, :filter_plugin, :whitelist_plugin,
      :sampled_as_boolean,
      :kafka_producer, :kafka_topic, :trace_id_128bit

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
      # Percentage of traces which by default this service traces (as float, 1.0 means 100%)
      @sample_rate       = config[:sample_rate]       || DEFAULTS[:sample_rate]
      # A block of code which can be called to do extra annotations of traces
      @annotate_plugin   = config[:annotate_plugin]   # call for trace annotation
      # A block of code which can be called to skip traces. Skip tracing if returns false
      @filter_plugin     = config[:filter_plugin]
      # A block of code which can be called to force sampling. Forces sampling if returns true
      @whitelist_plugin  = config[:whitelist_plugin]
      @logger            = Application.logger
      # Was the logger in fact setup by the client?
      @log_tracing       = config[:log_tracing]
      # When set to false, it uses 1/0 in the 'X-B3-Sampled' header, else uses true/false
      @sampled_as_boolean = config[:sampled_as_boolean].nil? ? DEFAULTS[:sampled_as_boolean] : config[:sampled_as_boolean]
      # The current default is true for compatibility but services are encouraged to move on.
      if @sampled_as_boolean
        @logger && @logger.warn("Using a boolean in the Sampled header is deprecated. Consider setting sampled_as_boolean to false")
      end

      # When set to true, high 8-bytes will be prepended to trace_id.
      # The upper 4-bytes are epoch seconds and the lower 4-bytes are random.
      # This makes it convertible to Amazon X-Ray trace ID format v1.
      # (See http://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-request-tracing.html)
      @trace_id_128bit = config[:trace_id_128bit].nil? ? DEFAULTS[:trace_id_128bit] : config[:trace_id_128bit]

      Trace.sample_rate = @sample_rate
      Trace.trace_id_128bit = @trace_id_128bit
    end

    def adapter
      if present?(@json_api_host)
        :json
      elsif present?(@zookeeper) && RUBY_PLATFORM == 'java'
        :kafka
      elsif @kafka_producer && @kafka_producer.respond_to?(:push)
        :kafka_producer
      elsif !!@log_tracing
        :logger
      else
        nil
      end
    end

    private

    DEFAULTS = {
      sample_rate: 0.1,
      sampled_as_boolean: true,
      trace_id_128bit: false
    }

    def present?(str)
      return false if str.nil?
      !!(/\A[[:space:]]*\z/ !~ str)
    end
  end
end
