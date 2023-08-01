module ZipkinTracer
  # This class manages the Zipkin related information in the Rack environment.
  # It is only used by the rack middleware.
  class ZipkinEnv
    attr_reader :env

    def initialize(env, config)
      @env    = env
      @config = config
    end

    def trace_id(default_flags = Trace::Flags::EMPTY)
      trace_id, span_id, parent_span_id, sampled, flags, shared = retrieve_or_generate_ids
      sampled = sampled_header_value(sampled)
      flags = (flags || default_flags).to_i
      Trace::TraceId.new(trace_id, parent_span_id, span_id, sampled, flags, shared)
    end

    def called_with_zipkin_b3_single_header?
      @called_with_zipkin_b3_single_header ||= @env.key?(B3_SINGLE_HEADER)
    end

    def called_with_zipkin_headers?
      @called_with_zipkin_headers ||= B3_REQUIRED_HEADERS.all? { |key| @env.key?(key) }
    end

    private

    B3_SINGLE_HEADER = 'HTTP_B3'.freeze
    B3_REQUIRED_HEADERS = %w[HTTP_X_B3_TRACEID HTTP_X_B3_SPANID].freeze
    B3_OPT_HEADERS = %w[HTTP_X_B3_PARENTSPANID HTTP_X_B3_SAMPLED HTTP_X_B3_FLAGS].freeze

    def supports_join?
      @config.supports_join
    end

    def retrieve_or_generate_ids
      if called_with_zipkin_b3_single_header?
        trace_id, span_id, parent_span_id, sampled, flags =
          B3SingleHeaderFormat.parse_from_header(@env[B3_SINGLE_HEADER])
        shared = true
      elsif called_with_zipkin_headers?
        trace_id, span_id, parent_span_id, sampled, flags = @env.values_at(*B3_REQUIRED_HEADERS, *B3_OPT_HEADERS)
        shared = true
      end

      unless supports_join?
        parent_span_id = span_id
        span_id = TraceGenerator.new.generate_id
        shared = false
      end

      unless trace_id
        span_id = TraceGenerator.new.generate_id
        trace_id = TraceGenerator.new.generate_id_from_span_id(span_id)
        parent_span_id = nil
        shared = false
      end

      [trace_id, span_id, parent_span_id, sampled, flags, shared]
    end

    def new_sampled_header_value(sampled)
      case [@config.sampled_as_boolean, sampled]
      when [true, true]
        'true'
      when [true, false]
        'false'
      when [false, true]
        '1'
      when [false, false]
        '0'
      end
    end

    def current_trace_sampled?
      rand < @config.sample_rate
    end

    def sampled_header_value(parent_trace_sampled)
      if parent_trace_sampled # A service upstream decided this goes in all the way
        parent_trace_sampled
      else
        new_sampled_header_value(force_sample? || current_trace_sampled? && !filtered? && traceable_request?)
      end
    end

    def force_sample?
      @config.whitelist_plugin && @config.whitelist_plugin.call(@env)
    end

    def filtered?
      @config.filter_plugin && !@config.filter_plugin.call(@env)
    end

    def traceable_request?
      return true unless @config.check_routes

      Application.routable_request?(@env)
    end
  end
end
