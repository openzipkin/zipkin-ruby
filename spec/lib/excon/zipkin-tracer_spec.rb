require 'spec_helper'
require 'zipkin-tracer/zipkin_null_tracer'

describe ZipkinTracer::ExconHandler do
  let(:tracer)   { Trace.tracer }
  let(:trace_id) { ::Trace::TraceId.new(1, 2, 3, true, ::Trace::Flags::DEBUG) }
  let(:hostname) { 'hostname.example.com' }
  let(:host_ip)  { 'hostname.example.com' }

  before do
    Trace.tracer = Trace::NullTracer.new
    Trace.push(trace_id)
    ::Trace.sample_rate = 1 # make sure initialized
    allow(::Trace).to receive(:default_endpoint).and_return(::Trace::Endpoint.new('127.0.0.1', '80', "foo service name"))
    allow(::Trace::Endpoint).to receive(:host_to_i32).with(hostname).and_return(host_ip)
  end

  it 'sets the X-B3 request headers with a new spanID' do
    WebMock.allow_net_connect!
    ENV["EXCON_DEBUG"] = "1"
    connection = Excon.new("http://127.0.0.1:8000", method: :get,
                           middlewares: Excon.defaults[:middlewares] + [ZipkinTracer::ExconHandler]
                          )
    response = connection.request
  end
end
