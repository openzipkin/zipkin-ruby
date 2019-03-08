require 'spec_helper'
require 'zipkin-tracer/zipkin_tracer_base'

describe Trace::ZipkinTracerBase do
  let(:span_id) { 'c3a555b04cf7e099' }
  let(:parent_id) { 'f0e71086411b1445' }
  let(:sampled) { true }
  let(:trace_id) { Trace::TraceId.new(span_id, nil, span_id, sampled, Trace::Flags::EMPTY) }
  let(:trace_id_with_parent) { Trace::TraceId.new(span_id, parent_id, span_id, sampled, Trace::Flags::EMPTY) }
  let(:rpc_name) { 'this_is_an_rpc' }
  let(:previous_rpc_name) { 'this_is_previous_rpc' }
  let(:tracer) { described_class.new }
  let(:default_endpoint) { Trace::Endpoint.new('127.0.0.1', '80', 'service_name') }
  let(:span_hash) { {
    name: rpc_name,
    traceId: span_id,
    id: span_id,
    localEndpoint: default_endpoint.to_h,
    timestamp: 1452987900000000,
    duration: 0,
    debug: false
  } }
  before do
    Timecop.freeze(Time.utc(2016, 1, 16, 23, 45, 0))
    allow(::Trace).to receive(:default_endpoint).and_return(default_endpoint)
  end

  describe '#flush!' do
    it 'raises if not implemented' do
      expect{ tracer.flush!}.to raise_error(StandardError, "not implemented")
    end
  end

  describe '#start_span' do
    let(:span) { tracer.start_span(trace_id, rpc_name) }
    let(:rpc_name) { 'this_is_an_rpc' }
    it 'sets the span name' do
      expect(span.name).to eq(rpc_name)
    end
    it 'sets the local endpoint' do
      expect(span.local_endpoint).to eq(default_endpoint)
    end
    context "no parentId" do
      it 'returns an empty span' do
        expect(span.annotations).to eq([])
        expect(span.tags).to eq({})
        expect(span.to_h).to eq(span_hash)
      end
    end
    context "with parentId" do
      let(:span) { tracer.start_span(trace_id_with_parent, rpc_name) }
      it 'returns an empty span' do
        expect(span.annotations).to eq([])
        expect(span.tags).to eq({})
        expect(span.to_h).to eq(span_hash.merge({parentId: parent_id}))
      end
    end
    it 'stores the span' do
      expect(tracer).to receive(:store_span).with(trace_id, anything)
      span
    end
  end

  describe '#end_span' do
    let(:span) { tracer.start_span(trace_id, rpc_name) }
    it 'closes the span' do
      span #touch it so it happens before we freeze time again
      Timecop.freeze(Time.utc(2016, 1, 16, 23, 45, 1))
      expect(tracer).to receive(:flush!)
      tracer.end_span(span)
      expect(span.to_h).to eq(span_hash.merge(duration: 1_000_000))
    end
    it 'flush if kind is SERVER in this span' do
      span.kind = Trace::Span::Kind::SERVER
      expect(tracer).to receive(:flush!)
      expect(tracer).to receive(:reset)
      tracer.end_span(span)
    end
    it 'flush if kind is CLIENT in this span and the span does not have parent span' do
      span.kind = Trace::Span::Kind::CLIENT
      expect(tracer).to receive(:flush!)
      expect(tracer).to receive(:reset)
      tracer.end_span(span)
    end
  end

  describe '#end_span with parent span' do
    let(:span) { tracer.start_span(trace_id_with_parent, rpc_name) }
    it 'does not flush if the current span has a parent span' do
      span.kind = Trace::Span::Kind::CLIENT
      expect(tracer).not_to receive(:flush!)
      expect(tracer).not_to receive(:reset)
      tracer.end_span(span)
    end
  end

  describe '#with_new_span' do
    let(:result) { 'result' }
    it 'returns the value of the block' do
      expect(tracer).to receive(:flush!)
      expect(tracer.with_new_span(trace_id, rpc_name) { result }).to eq(result)
    end

    it "yields the span to the block" do
      expect(tracer).to receive(:flush!)
      tracer.with_new_span(trace_id, rpc_name) do |span|
        expect(span.to_h[:traceId]).to eq(trace_id.trace_id.to_s)
      end
    end
    it 'starts and ends a span' do
      expect(tracer).to receive(:start_span)
      expect(tracer).to receive(:end_span)
      tracer.with_new_span(trace_id, rpc_name) { result }
    end
  end

end
