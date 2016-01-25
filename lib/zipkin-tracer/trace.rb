require 'finagle-thrift/trace'
require 'zipkin-tracer/zipkin_tracer_base'

module Trace

  # We need this to access the tracer from the Faraday middleware.
  def self.tracer
    @tracer
  end

  class Span
    attr_reader :size

    # We record information into spans, then we send these spans to zipkin
    def record(annotation)
      @size ||= 0
      case annotation
      when BinaryAnnotation
        binary_annotations << annotation
      when Annotation
        annotations << annotation
      end
      @size = @size + 1
    end

    def to_h
      {
        name: @name,
        traceId: @span_id.trace_id.to_s,
        id: @span_id.span_id.to_s,
        parentId: @span_id.parent_id.nil? ? nil : @span_id.parent_id.to_s,
        annotations: @annotations.map!(&:to_h),
        binaryAnnotations: @binary_annotations.map!(&:to_h),
        debug: @debug
      }
    end
  end

  class Annotation
    def to_h
      {
        value: @value,
        timestamp: @timestamp,
        endpoint: host.to_h
      }
    end
  end

  class BinaryAnnotation
    def to_h
      {
        key: @key,
        value: @value,
        endpoint: host.to_h
      }
    end
  end

  class Endpoint
    LOCALHOST = '127.0.0.1'
    LOCALHOST_I32 = 0x7f000001

    attr_accessor :ip_format

    # we cannot override the initializer to add an extra parameter so use a factory
    def self.make_endpoint(hostname, service_port, service_name, ip_format)
      ipv4 = begin
        hostname ||= Socket.gethostname
        ip_format == :string ? Socket.getaddrinfo(hostname, nil, :INET)[0][3] : host_to_i32(hostname)
      rescue
        ip_format == :string ? LOCALHOST : LOCALHOST_I32
      end

      ep = Endpoint.new(ipv4, service_port, service_name)
      ep.ip_format = ip_format
      ep
    end

    def to_h
      {
        ipv4: ipv4,
        port: port,
        serviceName: service_name
      }
    end
  end
end
