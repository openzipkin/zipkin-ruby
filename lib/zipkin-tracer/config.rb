require 'logger'
module ZipkinTracer

  class Config
    attr_reader :service_name, :service_port, :json_api_host, :traces_buffer,
      :scribe_server, :zookeeper, :sample_rate, :scribe_max_buffer, :annotate_plugin,
      :filter_plugin, :whitelist_plugin, :logger

    def initialize(app, config_hash)
      config = config_hash || app_config(app)
      @service_name      = config[:service_name]
      @service_port      = config[:service_port]      || DEFAULTS[:service_port]
      @json_api_host     = config[:json_api_host]
      @traces_buffer     = config[:traces_buffer]     || DEFAULTS[:traces_buffer]
      @scribe_server     = config[:scribe_server]
      @zookeeper         = config[:zookeeper]
      @sample_rate       = config[:sample_rate]       || DEFAULTS[:sample_rate]
      @scribe_max_buffer = config[:scribe_max_buffer] || DEFAULTS[:scribe_max_buffer]
      @annotate_plugin   = config[:annotate_plugin]   # call for trace annotation
      @filter_plugin     = config[:filter_plugin]     # skip tracing if returns false
      @whitelist_plugin  = config[:whitelist_plugin]  # force sampling if returns true
      @logger            = config[:logger]            || fallback_logger
    end

    def adapter
      if !!@json_api_host
        :json
      elsif !!@scribe_server
        :scribe
      elsif !!@zookeeper && RUBY_PLATFORM == 'java'
        :kafka
      else
        nil
      end
    end

    private

    def fallback_logger
      if defined?(Rails) # If we happen to be inside a Rails app, use its logger
        Rails.logger
      else
        Logger.new(STDOUT)
      end
    end

    DEFAULTS = {
      traces_buffer: 100,
      scribe_max_buffer: 10,
      sample_rate: 0.1,
      service_port: 80
    }

    def app_config(app)
      if app.respond_to?(:config) && app.config.respond_to?(:zipkin_tracer)
        app.config.zipkin_tracer
      else
        {}
      end
    end
  end
end
