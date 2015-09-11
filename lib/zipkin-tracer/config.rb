require 'logger'
module ZipkinTracer

  class Config
    attr_reader :service_name, :service_port, :scribe_server, :zookeeper, :sample_rate,
      :scribe_max_buffer, :annotate_plugin, :filter_plugin, :whitelist_plugin, :logger

    def initialize(app, config_hash)
      config = config_hash || app_config(app)
      @service_name      = config[:service_name]
      @service_port      = config[:service_port]
      @scribe_server     = config[:scribe_server]
      @zookeeper         = config[:zookeeper]
      @sample_rate       = config[:sample_rate]       || DEFAULTS[:sample_rate]
      @scribe_max_buffer = config[:scribe_max_buffer] || DEFAULTS[:scribe_max_buffer]
      @annotate_plugin   = config[:annotate_plugin]   # call for trace annotation
      @filter_plugin     = config[:filter_plugin]     # skip tracing if returns false
      @whitelist_plugin  = config[:whitelist_plugin]  # force sampling if returns true
      @logger            = config[:logger]            || fallback_logger
    end

    def using_scribe?
      !!(@scribe_server && defined?(::Scribe))
    end

    def using_kafka?
      !!(@zookeeper && RUBY_PLATFORM == 'java' && defined?(::Hermann))
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
      scribe_max_buffer: 10,
      sample_rate: 0.1
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
