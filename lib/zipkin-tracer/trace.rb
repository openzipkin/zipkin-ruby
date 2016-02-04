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

    # We record information into spans, then we send these spans to zipkin
    def record(annotation)
      case annotation
      when BinaryAnnotation
        binary_annotations << annotation
      when Annotation
        annotations << annotation
      end
    end

    def to_h
      {
        name: @name,
        traceId: @span_id.trace_id.to_s,
        id: @span_id.span_id.to_s,
        parentId: @span_id.parent_id.nil? ? nil : @span_id.parent_id.to_s,
        annotations: @annotations.map!(&:to_h),
        binaryAnnotations: @binary_annotations.map!(&:to_h),
        timestamp: @timestamp,
        duration: @duration,
        debug: @debug
      }
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
    LOCALHOST = '127.0.0.1'.freeze
    LOCALHOST_I32 = 0x7f000001.freeze
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
      ipv4 = begin
        ip_format == :string ? Socket.getaddrinfo(hostname, nil, :INET)[0][3] : host_to_i32(hostname)
      rescue
        ip_format == :string ? LOCALHOST : LOCALHOST_I32
      end

      ep = Endpoint.new(ipv4, service_port, service_name)
      ep.ip_format = ip_format
      ep
    end

  end
end
