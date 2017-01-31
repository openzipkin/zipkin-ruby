require 'spec_helper'
require 'zipkin-tracer/zipkin_null_tracer'
require 'lib/middleware_shared_examples'

describe ZipkinTracer::FaradayHandler do
  # allow stubbing of on_complete and response env
  class ResponseObject
    attr_reader :env

    def initialize(env, response_env)
      @env = env
      @response_env = response_env
    end

    def on_complete
      yield @response_env
      self
    end
  end

  let(:response_env) { { status: 200 } }
  let(:wrapped_app) { lambda { |env| ResponseObject.new(env, response_env) } }

  # returns the request headers
  def process(body, url, headers = {})
    env = {
      method: :post,
      url: url,
      body: body,
      request_headers: {}, #Faraday::Utils::Headers.new(headers),
    }
    middleware.call(env).env[:request_headers]
  end

  context 'middleware configured (without service_name)' do
    let(:middleware) { described_class.new(wrapped_app) }
    let(:service_name) { 'service' }

    context 'request with string URL' do
      let(:url) { raw_url }

      include_examples 'can make requests'
    end

    # in testing, Faraday v0.8.x passes a URI object rather than a string
    context 'request with pre-parsed URL' do
      let(:url) { URI.parse(raw_url) }

      include_examples 'can make requests'
    end
  end

  context 'configured with service_name "foo"' do
    let(:middleware) { described_class.new(wrapped_app, 'foo') }
    let(:service_name) { 'foo' }

    # in testing, Faraday v0.8.x passes a URI object rather than a string
    context 'request with pre-parsed URL' do
      let(:url) { URI.parse(raw_url) }

      include_examples 'can make requests'
    end
  end
end
