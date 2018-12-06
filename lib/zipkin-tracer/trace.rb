require 'finagle-thrift/trace'
require 'zipkin-tracer/zipkin_tracer_base'
# Module with a mix of functions and overwrites from the finagle implementation:
# https://github.com/twitter/finagle/blob/finagle-6.39.0/finagle-thrift/src/main/ruby/lib/finagle-thrift/trace.rb
module Trace
  attr_accessor :trace_id_128bit

  # We need this to access the tracer from the Faraday middleware.
  def self.tracer
    @tracer
  end

  def sample_rate
    @sample_rate
  end

  # A TraceId contains all the information of a given trace id
  # This class is defined in finagle-thrift. We are overwriting it here
  class TraceId
    attr_reader :trace_id, :parent_id, :span_id, :sampled, :flags

    def initialize(trace_id, parent_id, span_id, sampled, flags)
      @trace_id = Trace.trace_id_128bit ? TraceId128Bit.from_value(trace_id) : SpanId.from_value(trace_id)
      @parent_id = parent_id.nil? ? nil : SpanId.from_value(parent_id)
      @span_id = SpanId.from_value(span_id)
      @sampled = sampled
      @flags = flags
    end

    def next_id
      TraceId.new(@trace_id, @span_id, Trace.generate_id, @sampled, @flags)
    end

    # the debug flag is used to ensure the trace passes ALL samplers
    def debug?
      @flags & Flags::DEBUG == Flags::DEBUG
    end

    def sampled?
      debug? || ['1', 'true'].include?(@sampled)
    end

    def to_s
      "TraceId(trace_id = #{@trace_id.to_s}, parent_id = #{@parent_id.to_s}, span_id = #{@span_id.to_s}, sampled = #{@sampled.to_s}, flags = #{@flags.to_s})"
    end
  end

  # This class is the 128-bit version of the SpanId class:
  # https://github.com/twitter/finagle/blob/finagle-6.39.0/finagle-thrift/src/main/ruby/lib/finagle-thrift/trace.rb#L102
  class TraceId128Bit < SpanId
    HEX_REGEX_16 = /^[a-f0-9]{16}$/i
    HEX_REGEX_32 = /^[a-f0-9]{32}$/i
    MAX_SIGNED_I128 = (2 ** 128 / 2) -1
    MASK = (2 ** 128) - 1

    def self.from_value(v)
      if v.is_a?(String) && v =~ HEX_REGEX_16
        SpanId.new(v.hex)
      elsif v.is_a?(String) && v =~ HEX_REGEX_32
        new(v.hex)
      elsif v.is_a?(Numeric)
        new(v)
      elsif v.is_a?(SpanId)
        v
      end
    end

    def initialize(value)
      @value = value
      @i128 = if @value > MAX_SIGNED_I128
        -1 * ((@value ^ MASK) + 1)
      else
        @value
      end
    end

    def to_s; '%032x' % @value; end
    def to_i; @i128; end
  end

  # A span may contain many annotations
  # This class is defined in finagle-thrift. We are adding extra methods here
  class Span
    def initialize(name, span_id)
      @name = name
      @span_id = span_id
      @annotations = []
      @binary_annotations = []
      @debug = span_id.debug?
      @timestamp = to_microseconds(Time.now)
      @duration = UNKNOWN_DURATION
    end

    def close
      @duration = to_microseconds(Time.now) - @timestamp
    end

    def to_h
      h = {
        name: @name,
        traceId: @span_id.trace_id.to_s,
        id: @span_id.span_id.to_s,
        annotations: @annotations.map(&:to_h),
        binaryAnnotations: @binary_annotations.map(&:to_h),
        timestamp: @timestamp,
        duration: @duration,
        debug: @debug
      }
      h[:parentId] = @span_id.parent_id.to_s unless @span_id.parent_id.nil?
      h
    end

    # We record information into spans, then we send these spans to zipkin
    def record(value, endpoint = Trace.default_endpoint)
      annotations << Trace::Annotation.new(value.to_s, endpoint)
    end

    def record_tag(key, value, type = Trace::BinaryAnnotation::Type::STRING, endpoint = Trace.default_endpoint)
      binary_annotations << Trace::BinaryAnnotation.new(key, value.to_s, type, endpoint)
    end

    def record_local_component(value)
      record_tag(BinaryAnnotation::LOCAL_COMPONENT, value)
    end

    def has_parent_span?
      !@span_id.parent_id.nil?
    end

    private

    UNKNOWN_DURATION = 0 # mark duration was not set

    def to_microseconds(time)
      (time.to_f * 1_000_000).to_i
    end
  end

  # This class is defined in finagle-thrift. We are adding extra methods here
  class Annotation
    def to_h
      {
        value: @value,
        timestamp: @timestamp,
        endpoint: host.to_h
      }
    end
  end

  # This class is defined in finagle-thrift. We are adding extra methods here
  class BinaryAnnotation
    SERVER_ADDRESS = 'sa'.freeze
    URI = 'http.uri'.freeze
    METHOD = 'http.method'.freeze
    PATH = 'http.path'.freeze
    STATUS = 'http.status'.freeze
    LOCAL_COMPONENT = 'lc'.freeze
    ERROR = 'error'.freeze

    def to_h
      {
        key: @key,
        value: @value,
        endpoint: host.to_h
      }
    end
  end

  # This class is defined in finagle-thrift. We are adding extra methods here
  class Endpoint
    UNKNOWN_URL = 'unknown'.freeze

    # we cannot override the initializer to add an extra parameter so use a factory
    attr_accessor :ip_format

    def self.local_endpoint(service_port, service_name, ip_format)
      hostname = Socket.gethostname
      Endpoint.make_endpoint(hostname, service_port, service_name, ip_format)
    end

    def self.remote_endpoint(url, remote_service_name, ip_format)
      service_name = remote_service_name || url.host.split('.').first || UNKNOWN_URL # default to url-derived service name
      Endpoint.make_endpoint(url.host, url.port, service_name, ip_format)
    end

    def to_h
      {
        ipv4: ipv4,
        port: port,
        serviceName: service_name
      }
    end

    private
    def self.make_endpoint(hostname, service_port, service_name, ip_format)
      ep = Endpoint.new(hostname, service_port, service_name)
      ep.ip_format = ip_format
      ep
    end

  end
end
