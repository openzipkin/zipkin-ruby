require 'spec_helper'

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

  HEX_REGEX = /\A\h{16}\z/

  let(:response_env) { { status: 200 } }
  let(:wrapped_app) { lambda { |env| ResponseObject.new(env, response_env) } }

  let(:hostname) { 'service.example.com' }
  let(:host_ip) { 0x11223344 }
  let(:url_path) { '/some/path/here' }
  let(:raw_url) { "https://#{hostname}#{url_path}" }

  def process(body, url, headers = {})
    env = {
      method: :post,
      url: url,
      body: body,
      request_headers: Faraday::Utils::Headers.new(headers),
    }
    middleware.call(env)
  end

  before do
    ::Trace.sample_rate = 0.1 # make sure initialized
    allow(::Trace).to receive(:default_endpoint).and_return(::Trace::Endpoint.new('127.0.0.1', '80', service_name))
    allow(::Trace::Endpoint).to receive(:host_to_i32).with(hostname).and_return(host_ip)
  end

  shared_examples 'can make requests' do
    # helper to check host component of annotation
    def expect_host(host, host_ip, service_name)
      expect(host).to be_a_kind_of(::Trace::Endpoint)
      expect(host.ipv4).to eq(host_ip)
      expect(host.service_name).to eq(service_name)
    end

    def expect_tracing
      # expect SEND then RECV
      expect(::Trace).to receive(:set_rpc_name).with('post')

      expect(middleware).to receive(:record).with(instance_of(::Trace::BinaryAnnotation)) do |ann|
        expect(ann.key).to eq('http.uri')
        expect(ann.value).to eq(url_path)
      end

      expect(middleware).to receive(:record).with(instance_of(::Trace::BinaryAnnotation)) do |ann|
        expect(ann.key).to eq('sa')
        expect(ann.value).to eq('1')
        expect_host(ann.host, host_ip, service_name)
      end

      expect(middleware).to receive(:record).with(instance_of(::Trace::BinaryAnnotation)) do |ann|
        expect(ann.key).to eq('http.status')
        expect(ann.value).to eq('200')
      end

      expect(middleware).to receive(:record).with(instance_of(::Trace::Annotation)) do |ann|
        expect(ann.value).to eq(::Trace::Annotation::CLIENT_SEND)
        expect_host(ann.host, '127.0.0.1', service_name)
      end.ordered

      expect(middleware).to receive(:record).with(instance_of(::Trace::Annotation)) do |ann|
        expect(ann.value).to eq(::Trace::Annotation::CLIENT_RECV)
        expect_host(ann.host, '127.0.0.1', service_name)
      end.ordered
    end

    context 'with tracing id' do
      let(:trace_id) { ::Trace::TraceId.new(1, 2, 3, true, ::Trace::Flags::DEBUG) }

      it 'sets the X-B3 request headers with a new spanID' do
        expect_tracing
        result = nil
        ::Trace.push(trace_id) do
          result = process('', url).env
        end

        expect(result[:request_headers]['X-B3-TraceId']).to eq('0000000000000001')
        expect(result[:request_headers]['X-B3-ParentSpanId']).to eq('0000000000000003')
        expect(result[:request_headers]['X-B3-SpanId']).not_to eq('0000000000000003')
        expect(result[:request_headers]['X-B3-SpanId']).to match(HEX_REGEX)
        expect(result[:request_headers]['X-B3-Sampled']).to eq('true')
        expect(result[:request_headers]['X-B3-Flags']).to eq('1')
      end

      it 'the original spanID is restored after the calling the middleware' do
        ::Trace.push(trace_id)
        result = process('', url).env
        expect(::Trace.id).to eq(trace_id)
      end
    end

    context 'without tracing id' do
      after(:each) { ::Trace.pop }

      it 'generates a new ID, and sets the X-B3 request headers' do
        expect_tracing
        result = process('', url).env
        expect(result[:request_headers]['X-B3-TraceId']).to match(HEX_REGEX)
        expect(result[:request_headers]['X-B3-ParentSpanId']).to match(HEX_REGEX)
        expect(result[:request_headers]['X-B3-SpanId']).to match(HEX_REGEX)
        expect(result[:request_headers]['X-B3-Sampled']).to match(/(true|false)/)
        expect(result[:request_headers]['X-B3-Flags']).to match(/(1|0)/)
      end
    end

    context 'when looking up hostname raises' do
      let(:host_ip) { 0x7f000001 } # expect stubbed 'null' IP

      before do
        allow(::Trace::Endpoint).to receive(:host_to_i32).with(hostname).and_raise(SocketError)
      end

      it 'traces with stubbed endpoint address' do
        expect_tracing
        process('', url)
      end
    end

    it 'does not allow exceptions to raise to the application when ::Trace.record raises' do
      allow(::Trace).to receive(:record).and_raise(Errno::EBADF)
      expect{process('', url)}.not_to raise_error
    end

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
