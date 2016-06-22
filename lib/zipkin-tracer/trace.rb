require 'finagle-thrift/trace'
require 'zipkin-tracer/zipkin_tracer_base'

module Trace

  # We need this to access the tracer from the Faraday middleware.
  def self.tracer
    @tracer
  end

  def self.with_trace_id(trace_id, &block)
    self.push(trace_id)
    yield
  ensure
    self.pop
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
      annotations << Trace::Annotation.new(value, endpoint)
    end

    def record_tag(key, value, type = Trace::BinaryAnnotation::Type::STRING, endpoint = Trace.default_endpoint)
      binary_annotations << Trace::BinaryAnnotation.new(key, value, type, endpoint)
    end

    def record_local_component(value)
      record_tag(BinaryAnnotation::LOCAL_COMPONENT, value)
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
    STATUS = 'http.status'.freeze
    LOCAL_COMPONENT = 'lc'.freeze

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
