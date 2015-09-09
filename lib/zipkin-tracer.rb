require 'zipkin-tracer/rack/zipkin-tracer'

begin
  require 'faraday'
  require 'zipkin-tracer/faraday/zipkin-tracer'
rescue LoadError #Faraday is not available, we do not load our code.
end