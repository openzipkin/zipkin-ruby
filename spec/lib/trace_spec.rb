require 'spec_helper'

describe Trace do
  let(:dummy_endpoint) { Trace::Endpoint.new('127.0.0.1', 9411, 'DummyService') }
  let(:trace_id_128bit) { false }

  before do
    allow(Trace).to receive(:trace_id_128bit).and_return(trace_id_128bit)
  end

  it "id returns the next generator id" do
    expect_any_instance_of(ZipkinTracer::TraceGenerator).to receive(:current)
    Trace.id
  end

  describe Trace::TraceId do
    let(:traceid) { '234555b04cf7e099' }
    let(:span_id) { 'c3a555b04cf7e099' }
    let(:parent_id) { 'f0e71086411b1445' }
    let(:sampled) { true }
    let(:flags) { Trace::Flags::EMPTY }
    let(:shared) { false }
    let(:trace_id) { Trace::TraceId.new(traceid, parent_id, span_id, sampled, flags, shared) }

    it 'is not a debug trace' do
      expect(trace_id.debug?).to eq(false)
    end

    context 'sampled value is 0' do
      let(:sampled) { '0' }
      it 'is not sampled' do
        expect(trace_id.sampled?).to eq(false)
      end
    end
    context 'sampled value is false' do
      let(:sampled) { 'false' }
      it 'is sampled' do
        expect(trace_id.sampled?).to eq(false)
      end
    end
    context 'sampled value is 1' do
      let(:sampled) { '1' }
      it 'is sampled' do
        expect(trace_id.sampled?).to eq(true)
      end
    end
    context 'sampled value is true' do
      let(:sampled) { 'true' }
      it 'is sampled' do
        expect(trace_id.sampled?).to eq(true)
      end
    end

    context 'using the debug flag' do
      let(:flags) { Trace::Flags::DEBUG }
      it 'is a debug trace' do
        expect(trace_id.debug?).to eq(true)
      end
      it 'get sampled' do
        expect(trace_id.sampled?).to eq(true)
      end
    end

    context 'shared value is true' do
      let(:shared) { true }
      it 'is shared' do
        expect(trace_id.shared).to eq(true)
      end
    end

    context 'trace_id_128bit is false' do
      let(:traceid) { '5af30660491a5a27234555b04cf7e099' }

      it 'drops any bits higher than 64 bit' do
        expect(trace_id.trace_id.to_s).to eq('234555b04cf7e099')
      end
    end

    context 'trace_id_128bit is true' do
      let(:trace_id_128bit) { true }
      let(:traceid) { '5af30660491a5a27234555b04cf7e099' }

      it 'returns a 128-bit trace_id ' do
        expect(trace_id.trace_id.to_s).to eq(traceid)
      end
    end

    describe '#to_s' do
      it 'returns all information' do
        expect(trace_id.to_s).to eq(
          'TraceId(trace_id = 234555b04cf7e099, parent_id = f0e71086411b1445, span_id = c3a555b04cf7e099,' \
          ' sampled = true, flags = 0, shared = false)'
        )
      end
    end
  end

  describe Trace::TraceId128Bit do
    let(:traceid) { '234555b04cf7e099' }
    let(:traceid_128bit) { '5af30660491a5a27234555b04cf7e099' }
    let(:traceid_numeric) { 120892377080251878477690677995565998233 }
    let(:trace_id_128bit_instance) { described_class.from_value(traceid_128bit) }

    describe '.from_value' do
      it 'returns SpanId instance when traceid is 64-bit' do
        expect(described_class.from_value(traceid)).to be_instance_of(Trace::SpanId)
      end

      it 'returns TraceId128Bit instance when traceid is 128-bit' do
        expect(described_class.from_value(traceid_128bit)).to be_instance_of(described_class)
      end

      it 'returns TraceId128Bit instance when numeric value is given' do
        expect(described_class.from_value(traceid_numeric)).to be_instance_of(described_class)
      end

      it 'returns TraceId128Bit instance when TraceId128Bit instance is given' do
        expect(described_class.from_value(trace_id_128bit_instance)).to be_instance_of(described_class)
      end
    end

    describe '#to_s' do
      it 'returns trace_id value in string' do
        expect(trace_id_128bit_instance.to_s).to eq(traceid_128bit)
      end
    end

    describe '#to_i' do
      it 'returns trace_id value in integer' do
        expect(trace_id_128bit_instance.to_i).to eq(traceid_numeric)
      end
    end
  end

  describe Trace::Span do
    let(:span_id) { 'c3a555b04cf7e099' }
    let(:parent_id) { 'f0e71086411b1445' }
    let(:timestamp) { 1452987900000000 }
    let(:duration) { 0 }
    let(:key) { 'key' }
    let(:value) { 'value' }
    let(:numeric_value) { '123' }
    let(:span_without_parent) do
      Trace::Span.new('get', Trace::TraceId.new(span_id, nil, span_id, true, Trace::Flags::EMPTY))
    end
    let(:span_with_parent) do
      Trace::Span.new('get', Trace::TraceId.new(span_id, parent_id, span_id, true, Trace::Flags::EMPTY))
    end

    before do
      Timecop.freeze(Time.utc(2016, 1, 16, 23, 45))
      [span_with_parent, span_without_parent].each do |span|
        span.kind = Trace::Span::Kind::CLIENT
        span.local_endpoint = dummy_endpoint
        span.remote_endpoint = dummy_endpoint
        span.record(value)
        span.record_tag(key, value)
      end
    end

    describe '#to_h' do
      context 'client span' do
        let(:expected_hash) do
          {
            name: 'get',
            kind: 'CLIENT',
            traceId: span_id,
            localEndpoint: dummy_endpoint.to_h,
            remoteEndpoint: dummy_endpoint.to_h,
            id: span_id,
            debug: false,
            timestamp: timestamp,
            duration: duration,
            annotations: [{ timestamp: timestamp, value: "value" }],
            tags: { "key" => "value" }
          }
        end

        it 'returns a hash representation of a span' do
          expect(span_without_parent.to_h).to eq(expected_hash)
          expect(span_with_parent.to_h).to eq(expected_hash.merge(parentId: parent_id))
        end
      end

      context 'server span' do
        let(:shared_server_span) do
          Trace::Span.new('get', Trace::TraceId.new(span_id, nil, span_id, true, Trace::Flags::EMPTY, true))
        end
        let(:expected_hash) do
          {
            name: 'get',
            kind: 'SERVER',
            traceId: span_id,
            localEndpoint: dummy_endpoint.to_h,
            id: span_id,
            debug: false,
            timestamp: timestamp,
            duration: duration,
            shared: true
          }
        end

        before do
          shared_server_span.kind = Trace::Span::Kind::SERVER
          shared_server_span.local_endpoint = dummy_endpoint
        end

        it 'returns a hash representation of a span' do
          expect(shared_server_span.to_h).to eq(expected_hash)
        end
      end
    end

    describe '#record' do
      it 'records an annotation' do
        span_with_parent.record(value)

        ann = span_with_parent.annotations[-1]
        expect(ann.value).to eq('value')
      end

      it 'converts the value to string' do
        span_with_parent.record(numeric_value)

        ann = span_with_parent.annotations[-1]
        expect(ann.value).to eq('123')
      end
    end

    describe '#record_tag' do
      it 'records a tag' do
        span_with_parent.record_tag(key, value)

        tags = span_with_parent.tags
        expect(tags[key]).to eq('value')
      end

      it 'allows a numeric value' do
        span_with_parent.record_tag(key, numeric_value)

        tags = span_with_parent.tags
        expect(tags[key]).to eq('123')
      end
    end

    describe '#record_local_component' do
      it 'records a local_component tag' do
        span_with_parent.record_local_component(value)

        tags = span_with_parent.tags
        expect(tags['lc']).to eq('value')
      end
    end

  end

  describe Trace::Annotation do
    let(:annotation) { Trace::Annotation.new(Trace::Span::Tag::ERROR) }

    describe '#to_h' do
      before { Timecop.freeze(Time.utc(2016, 1, 16, 23, 45)) }

      it 'returns a hash representation of an annotation' do
        expect(annotation.to_h).to eq(
          value: 'error',
          timestamp: 1452987900000000
        )
      end
    end
  end

  describe Trace::Endpoint do
    let(:service_name) { 'service name' }
    let(:hostname) { 'z2.example.com' }

    describe '.local_endpoint' do
      it 'auto detects the hostname' do
        allow(Socket).to receive(:gethostname).and_return('z1.example.com')
        expect(Trace::Endpoint).to receive(:new).with('z1.example.com', nil, service_name, :string)
        Trace::Endpoint.local_endpoint(service_name, :string)
      end
    end

    describe '.make_endpoint' do
      context 'host lookup success' do
        before do
          allow(Socket).to receive(:getaddrinfo).with('z1.example.com', nil, :INET).
            and_return([['', '', '', '8.8.4.4']])
          allow(Socket).to receive(:getaddrinfo).with('z2.example.com', nil, :INET).
            and_return([['', '', '', '8.8.8.8']])
          allow(Socket).to receive(:getaddrinfo).with('z2.example.com', nil).
            and_return([['', '', '', '8.8.8.8']])
        end

        it 'does not translate the hostname' do
          ep = ::Trace::Endpoint.new(hostname, 80, service_name, :string)
          expect(ep.ipv4).to eq(hostname)
          expect(ep.ip_format).to eq(:string)
        end
      end
    end

    describe '#to_h' do
      context 'with service_port' do
        it 'returns a hash representation of an endpoint' do
          expect(dummy_endpoint.to_h).to eq(
            ipv4: '127.0.0.1',
            port: 9411,
            serviceName: 'DummyService'
          )
        end
      end

      context 'without service_port' do
        let(:dummy_endpoint) { Trace::Endpoint.new('127.0.0.1', nil, 'DummyService') }

        it 'returns a hash representation of an endpoint witout "port"' do
          expect(dummy_endpoint.to_h).to eq(
            ipv4: '127.0.0.1',
            serviceName: 'DummyService'
          )
        end
      end
    end
  end
end
