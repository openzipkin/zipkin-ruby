HEX_REGEX = /\A\h{16}\z/

shared_examples 'can make requests' do
  before do
    Trace.tracer = Trace::NullTracer.new
    Trace.push(trace_id)
    ::Trace.sample_rate = 1 # make sure initialized
    allow(::Trace).to receive(:default_endpoint).and_return(::Trace::Endpoint.new('127.0.0.1', '80', service_name))
    allow(::Trace::Endpoint).to receive(:host_to_i32).with(hostname).and_return(host_ip)
  end

  let(:hostname) { 'service.example.com' }
  let(:host_ip) { 0x11223344 }
  let(:url_path) { '/some/path/here' }
  let(:raw_url) { "https://#{hostname}#{url_path}" }
  let(:tracer) { Trace.tracer }
  let(:trace_id) { ::Trace::TraceId.new(1, 2, 3, true, ::Trace::Flags::DEBUG) }

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
      request_headers  = nil
      ::Trace.push(trace_id) do
        request_headers = process('', url)
      end

      expect(request_headers['X-B3-TraceId']).to eq('0000000000000001')
      expect(request_headers['X-B3-ParentSpanId']).to eq('0000000000000003')
      expect(request_headers['X-B3-SpanId']).not_to eq('0000000000000003')
      expect(request_headers['X-B3-SpanId']).to match(HEX_REGEX)
      expect(request_headers['X-B3-Sampled']).to eq('true')
      expect(request_headers['X-B3-Flags']).to eq('1')
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
      request_headers = process('', url)

      expect(request_headers['X-B3-TraceId']).to match(HEX_REGEX)
      expect(request_headers['X-B3-ParentSpanId']).to match(HEX_REGEX)
      expect(request_headers['X-B3-SpanId']).to match(HEX_REGEX)
      expect(request_headers['X-B3-Sampled']).to match(/(true|false)/)
      expect(request_headers['X-B3-Flags']).to match(/(1|0)/)
    end
  end

  context 'Trace has not been sampled' do
    let(:trace_id) { ::Trace::TraceId.new(1, 2, 3, false, 0) }

    it 'sets the X-B3 request headers with a new spanID' do
      request_headers = nil
      ::Trace.push(trace_id) do
        request_headers = process('', url)
      end

      expect(request_headers['X-B3-TraceId']).to eq('0000000000000001')
      expect(request_headers['X-B3-ParentSpanId']).to eq('0000000000000003')
      expect(request_headers['X-B3-SpanId']).not_to eq('0000000000000003')
      expect(request_headers['X-B3-SpanId']).to match(HEX_REGEX)
      expect(request_headers['X-B3-Sampled']).to eq('false')
      expect(request_headers['X-B3-Flags']).to eq('0')
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
