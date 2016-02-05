require 'logger'
require 'zipkin-tracer/application'

module ZipkinTracer
  # Configuration of this gem. It reads the configuration and provides default values
  class Config
    attr_reader :service_name, :service_port, :json_api_host,
      :scribe_server, :zookeeper, :sample_rate, :annotate_plugin,
      :filter_plugin, :whitelist_plugin, :logger

    def initialize(app, config_hash)
      config = config_hash || Application.config(app)
      @service_name      = config[:service_name]
      @service_port      = config[:service_port]      || DEFAULTS[:service_port]
      @json_api_host     = config[:json_api_host]
      @scribe_server     = config[:scribe_server]
      @zookeeper         = config[:zookeeper]
      @sample_rate       = config[:sample_rate]       || DEFAULTS[:sample_rate]
      @annotate_plugin   = config[:annotate_plugin]   # call for trace annotation
      @filter_plugin     = config[:filter_plugin]     # skip tracing if returns false
      @whitelist_plugin  = config[:whitelist_plugin]  # force sampling if returns true
      @logger            = config[:logger]            || Application.logger
    end

    def adapter
      if present?(@json_api_host)
        :json
      elsif present?(@scribe_server)
        :scribe
      elsif present?(@zookeeper) && RUBY_PLATFORM == 'java'
        :kafka
      else
        nil
      end
    end

    private

    DEFAULTS = {
      sample_rate: 0.1,
      service_port: 80
    }

    def present?(str)
      return false if str.nil?
      !!(/\A[[:space:]]*\z/ !~ str)
    end

  end
end
