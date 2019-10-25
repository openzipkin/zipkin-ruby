require 'zipkin-tracer/trace'
require 'zipkin-tracer/rack/zipkin-tracer'
require 'zipkin-tracer/sidekiq/middleware'
require 'zipkin-tracer/trace_client'
require 'zipkin-tracer/trace_container'
require 'zipkin-tracer/trace_generator'
require 'zipkin-tracer/trace_wrapper'
require 'zipkin-tracer/zipkin_b3_single_header_format'
require 'zipkin-tracer/zipkin_b3_header_helper'

begin
  require 'faraday'
  require 'zipkin-tracer/faraday/zipkin-tracer'
rescue LoadError # Faraday is not available, we do not load our code.
end

begin
  require 'excon'
  require 'zipkin-tracer/excon/zipkin-tracer'
rescue LoadError
end
