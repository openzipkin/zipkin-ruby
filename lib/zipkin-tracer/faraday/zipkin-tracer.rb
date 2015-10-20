require 'faraday'
require 'finagle-thrift'
require 'finagle-thrift/trace'
require 'uri'

module ZipkinTracer
  class FaradayHandler < ::Faraday::Middleware
    B3_HEADERS = {
      :trace_id => "X-B3-TraceId",
      :parent_id => "X-B3-ParentSpanId",
      :span_id => "X-B3-SpanId",
      :sampled => "X-B3-Sampled",
      :flags => "X-B3-Flags"
    }.freeze

    def initialize(app, service_name=nil)
      @app = app
      @service_name = service_name
    end

    def call(env)
      # handle either a URI object (passed by Faraday v0.8.x in testing), or something string-izable
      url = env[:url].respond_to?(:host) ? env[:url] : URI.parse(env[:url].to_s)
      service_name = @service_name || url.host.split('.').first # default to url-derived service name

      endpoint = ::Trace::Endpoint.new(host_ip_for(url.host), url.port, service_name)
      response = nil
      begin
        trace_id = ::Trace.id
        ::Trace.push(trace_id.next_id)
        B3_HEADERS.each do |method, header|
          env[:request_headers][header] = ::Trace.id.send(method).to_s
        end
        # annotate with method (GET/POST/etc.) and uri path
        ::Trace.set_rpc_name(env[:method].to_s.upcase)
        record(::Trace::BinaryAnnotation.new("http.uri", url.path, "STRING", endpoint))
        record(::Trace::Annotation.new(::Trace::Annotation::CLIENT_SEND, endpoint))
        response = @app.call(env).on_complete do |renv|
          # record HTTP status code on response
          record(::Trace::BinaryAnnotation.new("http.status", renv[:status].to_s, "STRING", endpoint))
        end
        record(::Trace::Annotation.new(::Trace::Annotation::CLIENT_RECV, endpoint))
      ensure
        ::Trace.pop
      end
      response
    end

    private

    def record(annotation)
      ::Trace.record(annotation)
    rescue Exception # Sockets errors inherit from Exception, not from StandardError
      #TODO: if this class some day accepts a config hash, add a logger
    end

    # get host IP for specified hostname, catching exceptions
    def host_ip_for(hostname)
      ::Trace::Endpoint.host_to_i32(hostname)
    rescue
      # default to 0.0.0.0 if lookup fails
      0x00000000
    end

  end
end
