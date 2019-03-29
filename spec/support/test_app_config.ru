require 'zipkin-tracer'
require 'base64'
require File.join(`pwd`.chomp, 'spec', 'support', 'test_app')

zipkin_tracer_config = {
  service_name: 'your service name here',
  sample_rate: 1,
  json_api_host: '127.0.0.1:9410',
  sampled_as_boolean: false
}

use ZipkinTracer::RackHandler, zipkin_tracer_config
run TestApp.new
