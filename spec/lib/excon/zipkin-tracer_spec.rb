require 'spec_helper'
require 'zipkin-tracer/zipkin_null_tracer'

describe ZipkinTracer::ExconHandler do
  let(:response_env) { { status: 200 } }
  let(:wrapped_app) { lambda { |env| ResponseObject.new(env, response_env) } }

  let(:hostname) { 'service.example.com' }
  let(:host_ip) { 0x11223344 }
  let(:url_path) { '/some/path/here' }
  let(:raw_url) { "https://#{hostname}#{url_path}" }
  let(:tracer) { Trace.tracer }
  let(:trace_id) { ::Trace::TraceId.new(1, 2, 3, true, ::Trace::Flags::DEBUG) }

  before do
    Excon.defaults[:middlewares].unshift(ZipkinTracer::ExconHandler)
    Excon.defaults[:mock] = true
    Excon.stub({ path: '/' }, body: 'index')
    Excon.stub({ path: '/hello' }, body: 'world')
    Excon.stub({ path: '/hello', query: 'message=world' }, body: 'hi!')
    Excon.stub({ path: '/world' }, body: 'universe')

    Trace.tracer = Trace::NullTracer.new
    Trace.push(trace_id)
    ::Trace.sample_rate = 1 # make sure initialized
    service_name = "foo service name"
    allow(::Trace).to receive(:default_endpoint).and_return(::Trace::Endpoint.new('127.0.0.1', '80', service_name))
    allow(::Trace::Endpoint).to receive(:host_to_i32).with(hostname).and_return(host_ip)
  end

  it 'should do something' do
    connection = Excon.new(raw_url)
    response = connection.get

    assert_equal 'world', response.body
  end
end
