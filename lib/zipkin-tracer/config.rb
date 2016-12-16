require 'logger'
require 'zipkin-tracer/application'

module ZipkinTracer
  # Configuration of this gem. It reads the configuration and provides default values
  class Config
    attr_reader :service_name, :service_port, :json_api_host,
      :zookeeper, :sample_rate, :logger, :log_tracing,
      :annotate_plugin, :filter_plugin, :whitelist_plugin,
      :sampled_as_boolean

    def initialize(app, config_hash)
      config = config_hash || Application.config(app)
      # The name of the current service
      @service_name      = config[:service_name]
      # The port where the current service is running
      @service_port      = config[:service_port]      || DEFAULTS[:service_port]
      # The address of the Zipkin server which we will send traces to
      @json_api_host     = config[:json_api_host]
      # Zookeeper information
      @zookeeper         = config[:zookeeper]
      # Percentage of traces which by default this service traces (as float, 1.0 means 100%)
      @sample_rate       = config[:sample_rate]       || DEFAULTS[:sample_rate]
      # A block of code which can be called to do extra annotations of traces
      @annotate_plugin   = config[:annotate_plugin]   # call for trace annotation
      @filter_plugin     = config[:filter_plugin]     # skip tracing if returns false
      @whitelist_plugin  = config[:whitelist_plugin]  # force sampling if returns true
      # A block of code which can be called to skip traces. Skip tracing if returns false
      @filter_plugin     = config[:filter_plugin]
      # A block of code which can be called to force sampling. Forces sampling if returns true
      @whitelist_plugin  = config[:whitelist_plugin]
      @logger            = Application.logger
      @log_tracing       = config[:log_tracing]       # Was the logger in fact setup by the client?
      # Was the logger in fact setup by the client?
      @log_tracing       = config[:log_tracing]
      # When set to false, it uses 1/0 in the 'X-B3-Sampled' header, else uses true/false
      @sampled_as_boolean = config[:sampled_as_boolean] || DEFAULTS[:sampled_as_boolean]
      # The current default is true for compatibility but services are encouraged to move on.
      if @sampled_as_boolean
        @logger && @logger.warn("Using a boolean in the Sampled header is deprecated. Consider setting sampled_as_boolean to false")
      end
      Trace.sample_rate = @sample_rate
    end

    def adapter
      if present?(@json_api_host)
        :json
      elsif present?(@zookeeper) && RUBY_PLATFORM == 'java'
        :kafka
      elsif !!@log_tracing
        :logger
      else
        nil
      end
    end

    private

    DEFAULTS = {
      sample_rate: 0.1,
      service_port: 80,
      sampled_as_boolean: true
    }

    def present?(str)
      return false if str.nil?
      !!(/\A[[:space:]]*\z/ !~ str)
    end

  end
end
