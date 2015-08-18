# Copyright 2012 Twitter Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
require 'finagle-thrift'
require 'finagle-thrift/trace'
require 'scribe'

require 'zipkin-tracer/careless_scribe'

if RUBY_PLATFORM == 'java'
  require 'hermann/producer'
  require 'zipkin-tracer/zipkin_kafka_tracer'
end

module ZipkinTracer extend self

  class RackHandler
    B3_REQUIRED_HEADERS = %w[HTTP_X_B3_TRACEID HTTP_X_B3_PARENTSPANID HTTP_X_B3_SPANID HTTP_X_B3_SAMPLED]
    B3_OPT_HEADERS = %w[HTTP_X_B3_FLAGS]

    def initialize(app, config=nil)
      @app = app
      @lock = Mutex.new

      config ||= app.config.zipkin_tracer # if not specified, try on app (e.g. Rails 3+)
      @service_name = config[:service_name]
      @service_port = config[:service_port]

      ::Trace.tracer = if config[:scribe_server] && defined?(::Scribe)
        scribe = config[:scribe_server] ? Scribe.new(config[:scribe_server]) : Scribe.new()
        scribe_max_buffer = config[:scribe_max_buffer] ? config[:scribe_max_buffer] : 10
        ::Trace::ZipkinTracer.new(CarelessScribe.new(scribe), scribe_max_buffer)
      elsif config[:zookeeper] && RUBY_PLATFORM == 'java' && defined?(::Hermann)
        kafkaTracer = ::Trace::ZipkinKafkaTracer.new
        kafkaTracer.connect(config[:zookeeper])
        kafkaTracer
      end

      @sample_rate = config[:sample_rate] ? config[:sample_rate] : 0.1
      @annotate_plugin = config[:annotate_plugin]     # call for trace annotation
      @filter_plugin = config[:filter_plugin]         # skip tracing if returns false
      @whitelist_plugin = config[:whitelist_plugin]   # force sampling if returns true
    end

    def call(env)
      # skip certain requests
      return @app.call(env) if filtered?(env)

      ::Trace.default_endpoint = ::Trace.default_endpoint.with_service_name(@service_name).with_port(@service_port)
      ::Trace.sample_rate=(@sample_rate)
      whitelisted = force_sample?(env)
      id = get_or_create_trace_id(env, whitelisted) # note that this depends on the sample rate being set
      tracing_filter(id, env, whitelisted) { @app.call(env) }
    end

    private
    def annotate(env, status, response_headers, response_body)
      @annotate_plugin.call(env, status, response_headers, response_body) if @annotate_plugin
    end

    def filtered?(env)
      @filter_plugin && !@filter_plugin.call(env)
    end

    def force_sample?(env)
      @whitelist_plugin && @whitelist_plugin.call(env)
    end

    def tracing_filter(trace_id, env, whitelisted=false)
      @lock.synchronize do
        ::Trace.push(trace_id)
        ::Trace.set_rpc_name(env["REQUEST_METHOD"]) # get/post and all that jazz
        ::Trace.record(::Trace::BinaryAnnotation.new("http.uri", env["PATH_INFO"], "STRING", ::Trace.default_endpoint))
        ::Trace.record(::Trace::Annotation.new(::Trace::Annotation::SERVER_RECV, ::Trace.default_endpoint))
        ::Trace.record(::Trace::Annotation.new('whitelisted', ::Trace.default_endpoint)) if whitelisted
      end
      status, headers, body = yield if block_given?
    ensure
      @lock.synchronize do
        ::Trace.record(::Trace::Annotation.new(::Trace::Annotation::SERVER_SEND, ::Trace.default_endpoint))
        annotate(env, status, headers, body)
        ::Trace.pop
      end
    end

    private
    def get_or_create_trace_id(env, whitelisted, default_flags = ::Trace::Flags::EMPTY)
      trace_parameters = if B3_REQUIRED_HEADERS.all? { |key| env.has_key?(key) }
                           env.values_at(*B3_REQUIRED_HEADERS)
                         else
                           new_id = Trace.generate_id
                           [new_id, nil, new_id, ("true" if whitelisted || Trace.should_sample?)]
                         end
      trace_parameters[3] = (trace_parameters[3] == "true")

      trace_parameters += env.values_at(*B3_OPT_HEADERS) # always check flags
      trace_parameters[4] = (trace_parameters[4] || default_flags).to_i

      Trace::TraceId.new(*trace_parameters)
    end
  end

end
