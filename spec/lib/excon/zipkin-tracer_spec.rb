require 'spec_helper'
require 'zipkin-tracer/zipkin_null_tracer'

describe ZipkinTracer::ExconHandler do
  let(:hostname) { 'service.example.com' }
  let(:host_ip)  { 0x11223344 }
  let(:url_path) { '/some/path/here' }
  let(:raw_url)  { "https://#{hostname}#{url_path}" }
  let(:tracer)   { Trace.tracer }
  let(:trace_id) { ::Trace::TraceId.new(1, 2, 3, true, ::Trace::Flags::DEBUG) }


  before do
    # Excon.defaults[:mock] = true
    # Excon.stub({ path: url_path }, body: 'world')

    Trace.tracer = Trace::NullTracer.new
    Trace.push(trace_id)
    ::Trace.sample_rate = 1 # make sure initialized

    allow(::Trace).to receive(:default_endpoint).and_return(::Trace::Endpoint.new('127.0.0.1', '80', "foo service name"))
    allow(::Trace::Endpoint).to receive(:host_to_i32).with(hostname).and_return(host_ip)
  end

  context 'with tracing id' do
    let(:trace_id) { ::Trace::TraceId.new(1, 2, 3, true, ::Trace::Flags::DEBUG) }

    it 'sets the X-B3 request headers with a new spanID' do
      connection = Excon.new("https://www.google.com/",
                      method: :get,
                      middlewares: Excon.defaults[:middlewares] + [ZipkinTracer::ExconHandler]
                   )
      response = connection.request

      expect(request.data[:headers]['X-B3-TraceId']).to eq('0000000000000001')
      expect(request.data[:headers]['X-B3-ParentSpanId']).to eq('0000000000000003')
      expect(request.data[:headers]['X-B3-SpanId']).not_to eq('0000000000000003')
      expect(request.data[:headers]['X-B3-SpanId']).to match(HEX_REGEX)
      expect(request.data[:headers]['X-B3-Sampled']).to eq('true')
      expect(request.data[:headers]['X-B3-Flags']).to eq('1')
    end
  end
end
