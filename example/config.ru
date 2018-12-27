require 'zipkin-tracer'
require 'rack'
require_relative 'tracer_config'
require_relative 'my_app'

use ZipkinTracer::RackHandler, ZIPKIN_TRACER_CONFIG
run MyApp
