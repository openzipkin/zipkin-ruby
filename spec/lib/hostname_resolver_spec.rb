require 'spec_helper'
require 'zipkin-tracer/hostname_resolver'

describe ZipkinTracer::HostnameResolver do
  let(:span_id) { 'c3a555b04cf7e099' }
  let(:parent_id) { 'f0e71086411b1445' }
  let(:sampled) { true }
  let(:trace_id) { Trace::TraceId.new(span_id, nil, span_id, sampled, Trace::Flags::EMPTY) }
  let(:name) { 'raist' }
  let(:ipv4) { '100.100.100.100' }
  let(:hostname) { 'www.trusmis.com' }
  let(:endpoint) { Trace::Endpoint.new(hostname, 80, name) }
  let(:span) { Trace::Span.new(name, trace_id) }
  let(:resolved_spans) { described_class.new.spans_with_ips([span]) }

  context 'no spans' do
    it 'returns an empty array' do
      expect(described_class.new.spans_with_ips([])).to eq([])
    end
  end

  context 'with spans' do
    before do
      endpoint.ip_format = :string
      Trace.default_endpoint = endpoint
      span.record('diary')
      span.record_tag('secret', 'book')
      allow(Socket).to receive(:getaddrinfo).with(hostname, nil, :INET).and_return([[nil, nil, nil, ipv4]])
    end

    it 'returns an array of spans' do
      expect(resolved_spans).to be_kind_of(Array)
    end

    it 'The returned array contains spans' do
      expect(resolved_spans.first).to be_kind_of(Trace::Span)
    end

    it 'resolves the hostnames in the annotations' do
      ip = resolved_spans.first.annotations.first.host.ipv4
      expect(ip).to eq(ipv4)
    end

    it 'resolves the hostnames in the binnary annotations' do
      ip = resolved_spans.first.binary_annotations.first.host.ipv4
      expect(ip).to eq(ipv4)
    end

    context 'host lookup failure' do
      before { allow(Socket).to receive(:getaddrinfo).and_raise }
      context 'i32' do
       before { endpoint.ip_format = :i32 }
        it 'falls back to localhost as an i32' do
          ip = resolved_spans.first.annotations.first.host.ipv4
          expect(ip).to eq(0x7f000001)
        end
      end

      context 'string' do
        before { endpoint.ip_format = :string }
        it 'falls back to localhost as an string' do
          ip = resolved_spans.first.annotations.first.host.ipv4
          expect(ip).to eq('127.0.0.1')
        end
      end
    end

  end
end
