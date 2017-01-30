require 'spec_helper'
require 'zipkin-tracer/zipkin_null_tracer'

describe ZipkinTracer::ExconHandler do
  HEX_REGEX = /\A\h{16}\z/

  let(:hostname) { 'service.example.com' }
  let(:host_ip) { 0x11223344 }
  let(:url_path) { '/some/path/here' }
  let(:raw_url) { "https://#{hostname}#{url_path}" }
  let(:tracer) { Trace.tracer }
  let(:trace_id) { ::Trace::TraceId.new(1, 2, 3, true, ::Trace::Flags::DEBUG) }

  def process(body, url, headers = {})
    ENV['ZIPKIN_SERVICE_NAME'] = service_name
    connection = Excon.new(raw_url,
                           method: :post,
                           middlewares: [ZipkinTracer::ExconHandler] + Excon.defaults[:middlewares]
                          )
    connection.request
  end

  before do
    stub_request(:post, raw_url).to_return(:status => 200, :body => "", :headers => {})

    Trace.tracer = Trace::NullTracer.new
    Trace.push(trace_id)
    ::Trace.sample_rate = 1 # make sure initialized
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
      expect(tracer).to receive(:with_new_span).with(anything, 'post').and_call_original

      expect_any_instance_of(Trace::Span).to receive(:record_tag) do |_, key, value, type, host|
        expect(key).to eq('http.path')
        expect(value).to eq(url_path)
        expect_host(host, '127.0.0.1', service_name)
      end

      expect_any_instance_of(Trace::Span).to receive(:record_tag) do |_, key, value, type, host|
        expect(key).to eq('sa')
        expect(value).to eq('1')
        expect(type).to eq('BOOL')
        expect_host(host, hostname, service_name)
      end

      expect_any_instance_of(Trace::Span).to receive(:record_tag) do |_, key, value, type, host|
        expect(key).to eq('http.status')
        expect(value).to eq('200')
        expect_host(host, '127.0.0.1', service_name)
      end

      expect_any_instance_of(Trace::Span).to receive(:record) do |_, value, host|
        expect(value).to eq(Trace::Annotation::CLIENT_SEND)
        expect_host(host, '127.0.0.1', service_name)
      end

      expect_any_instance_of(Trace::Span).to receive(:record) do |_, value, host|
        expect(value).to eq(Trace::Annotation::CLIENT_RECV)
        expect_host(host, '127.0.0.1', service_name)
      end
    end

    context 'with tracing id' do
      let(:trace_id) { ::Trace::TraceId.new(1, 2, 3, true, ::Trace::Flags::DEBUG) }

      it 'sets the X-B3 request headers with a new spanID' do
        expect_tracing
        result = nil
        ::Trace.push(trace_id) do
          process('', url)
        end

        expect(a_request(:post, raw_url).with { |req| 
          req.headers['X-B3-Traceid'] == '0000000000000001' &&
          req.headers['X-B3-Parentspanid'] == '0000000000000003' &&
          req.headers['X-B3-Spanid'] != '0000000000000003' &&
          req.headers['X-B3-Spanid'] =~ HEX_REGEX &&
          req.headers['X-B3-Sampled'] == 'true' &&
          req.headers['X-B3-Flags'] == '1'
        }).to have_been_made
      end

      it 'the original spanID is restored after the calling the middleware' do
        old_trace_id = Trace.id
        ::Trace.push(trace_id) do
          process('', url)
        end
        expect(::Trace.id).to eq(old_trace_id)
      end
    end

    context 'without tracing id' do
      after(:each) { ::Trace.pop }

      it 'generates a new ID, and sets the X-B3 request headers' do
        expect_tracing
        process('', url)

        expect(a_request(:post, raw_url).with { |req| 
          req.headers['X-B3-Traceid'] =~ HEX_REGEX &&
          req.headers['X-B3-Parentspanid'] =~ HEX_REGEX &&
          req.headers['X-B3-Spanid'] =~ HEX_REGEX &&
          req.headers['X-B3-Sampled'] =~ /(true|false)/ &&
          req.headers['X-B3-Flags'] =~ /(1|0)/
        }).to have_been_made
      end
    end

    context 'Trace has not been sampled' do
      let(:trace_id) { ::Trace::TraceId.new(1, 2, 3, false, 0) }

      it 'sets the X-B3 request headers with a new spanID' do
        result = nil
        ::Trace.push(trace_id) do
          process('', url)
        end

        expect(a_request(:post, raw_url).with { |req| 
          req.headers['X-B3-Traceid'] == '0000000000000001' &&
          req.headers['X-B3-Parentspanid'] == '0000000000000003' &&
          req.headers['X-B3-Spanid'] != '0000000000000003' &&
          req.headers['X-B3-Spanid'] =~ HEX_REGEX &&
          req.headers['X-B3-Sampled'] == 'false' &&
          req.headers['X-B3-Flags'] == '0'
        }).to have_been_made
      end

      it 'the original spanID is restored after the calling the middleware' do
        old_trace_id = Trace.id
        ::Trace.push(trace_id) do
          process('', url)
        end
        expect(::Trace.id).to eq(old_trace_id)
      end

      it 'does not trace the request' do
        expect(tracer).not_to receive(:set_rpc_name)
        expect(tracer).not_to receive(:record)
        ::Trace.push(trace_id) do
           process('', url)
        end
      end

      it 'does not create any annotation' do
        expect(Trace::BinaryAnnotation).not_to receive(:new)
        expect(Trace::Annotation).not_to receive(:new)
        ::Trace.push(trace_id) do
           process('', url)
        end
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

  end


  context 'middleware configured (without service_name)' do
    let(:service_name) { 'service2' }

    context 'request with string URL' do
      let(:url) { raw_url }

      include_examples 'can make requests'
    end

    context 'request with pre-parsed URL' do
      let(:url) { URI.parse(raw_url) }

      include_examples 'can make requests'
    end
  end

  context 'configured with service_name "foo"' do
    let(:service_name) { 'foo' }

    context 'request with pre-parsed URL' do
      let(:url) { URI.parse(raw_url) }

      include_examples 'can make requests'
    end
  end
end
