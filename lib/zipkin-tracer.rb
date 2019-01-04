require 'zipkin-tracer/trace'
require 'zipkin-tracer/rack/zipkin-tracer'
require 'zipkin-tracer/sidekiq/middleware'
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
