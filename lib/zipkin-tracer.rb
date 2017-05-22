require 'finagle-thrift'
require 'base64' #Bug in finagle. They should be requiring this: finagle-thrift-1.4.1/lib/finagle-thrift/tracer.rb:115
require 'zipkin-tracer/trace'
require 'zipkin-tracer/rack/zipkin-tracer'
require 'zipkin-tracer/trace_client'
require 'zipkin-tracer/trace_container'
require 'zipkin-tracer/trace_generator'

begin
  require 'faraday'
  require 'zipkin-tracer/faraday/zipkin-tracer'
rescue LoadError #Faraday is not available, we do not load our code.
end

begin
  require 'excon'
  require 'zipkin-tracer/excon/zipkin-tracer'
rescue LoadError
end
