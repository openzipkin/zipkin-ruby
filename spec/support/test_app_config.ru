require 'zipkin-tracer'
require 'base64'
require File.join(`pwd`.chomp, 'spec', 'support', 'test_app')

zipkin_tracer_config = {
  service_name: 'your service name here',
  service_port: 9410,
  sample_rate: 1,
  traces_buffer: 1,
  json_api_host: '127.0.0.1:9410'
}

use ZipkinTracer::RackHandler, zipkin_tracer_config
run TestApp.new
