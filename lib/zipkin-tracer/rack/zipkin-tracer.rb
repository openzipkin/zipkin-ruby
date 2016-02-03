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
require 'finagle-thrift/trace'
require 'finagle-thrift/tracer'
require 'zipkin-tracer/config'
require 'zipkin-tracer/tracer_factory'

module ZipkinTracer

  # This middleware reads Zipkin headers from the request and sets/creates a Trace.id usable by the rest of the app
  # It will also send the trace to the Zipkin service using one of the methods configured.
  class RackHandler
    B3_REQUIRED_HEADERS = %w[HTTP_X_B3_TRACEID HTTP_X_B3_PARENTSPANID HTTP_X_B3_SPANID HTTP_X_B3_SAMPLED]
    B3_OPT_HEADERS = %w[HTTP_X_B3_FLAGS]

    def initialize(app, config = nil)
      @app = app
      @lock = Mutex.new
      @config = Config.new(app, config).freeze
      @tracer = TracerFactory.new.tracer(@config)
    end

    def call(env)
      zipkin_env = ZipkinEnv.new(env, @config)
      trace_id = zipkin_env.trace_id
      Trace.with_trace_id(trace_id) do
        if !trace_id.sampled? || !routable_request?(env)
          @app.call(env)
        else
          @tracer.with_new_span(trace_id, zipkin_env.env['REQUEST_METHOD'].to_s.downcase) do |span|
            trace!(span, zipkin_env) { @app.call(env) }
          end
        end
      end
    end

    private

    # If the request is not valid for this service, we do not what to trace it.
    def routable_request?(env)
      return true unless defined?(Rails) # If not running on a Rails app, we can't verify if it is invalid
      Rails.application.routes.recognize_path(env['PATH_INFO'])
      true
    rescue ActionController::RoutingError
      false
    end

    def annotate_plugin(env, status, response_headers, response_body)
      @config.annotate_plugin.call(env, status, response_headers, response_body) if @config.annotate_plugin
    end

    def trace!(span, zipkin_env, &block)
      synchronize do
        #if called by a service, the caller already added the information
        trace_request_information(span, zipkin_env.env) unless zipkin_env.called_with_zipkin_headers?
        span.record(Trace::Annotation.new(Trace::Annotation::SERVER_RECV, Trace.default_endpoint))
        span.record(Trace::Annotation.new('whitelisted', Trace.default_endpoint)) if zipkin_env.force_sample?
      end
      status, headers, body = yield
    ensure
      synchronize do
        annotate_plugin(zipkin_env.env, status, headers, body)
        span.record(Trace::Annotation.new(Trace::Annotation::SERVER_SEND, Trace.default_endpoint))
      end
    end

    def trace_request_information(span, env)
      span.record(Trace::BinaryAnnotation.new('http.uri', env['PATH_INFO'], 'STRING', Trace.default_endpoint))
    end

    def synchronize(&block)
      @lock.synchronize do
        yield
      end
    rescue => e
      @config.logger.error("Exception #{e.message} while sending Zipkin traces. #{e.backtrace}")
    end

    # Environment with Zipkin information in it
    class ZipkinEnv
      attr_reader :env

      def initialize(env, config)
        @env    = env
        @config = config
      end

      def trace_id(default_flags = Trace::Flags::EMPTY)
        trace_parameters = if called_with_zipkin_headers?
                             @env.values_at(*B3_REQUIRED_HEADERS)
                           else
                             new_id = Trace.generate_id
                             [new_id, nil, new_id]
                           end
        trace_parameters[3] = should_trace?(trace_parameters[3])
        trace_parameters += @env.values_at(*B3_OPT_HEADERS) # always check flags
        trace_parameters[4] = (trace_parameters[4] || default_flags).to_i

        Trace::TraceId.new(*trace_parameters)
      end

      def called_with_zipkin_headers?
        @called_with_zipkin_headers ||= B3_REQUIRED_HEADERS.all? { |key| @env.has_key?(key) }
      end

      def force_sample?
        @force_sample ||= @config.whitelist_plugin && @config.whitelist_plugin.call(@env)
      end

      private

      def current_trace_sampled?
        rand < @config.sample_rate
      end

      def should_trace?(parent_trace_sampled)
        if parent_trace_sampled  # A service upstream decided this goes in all the way
          parent_trace_sampled == 'true'
        else
          force_sample? || current_trace_sampled? && !filtered?
        end
      end

      def filtered?
        @config.filter_plugin && !@config.filter_plugin.call(@env)
      end
    end

  end
end
