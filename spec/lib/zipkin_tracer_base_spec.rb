require 'spec_helper'
require 'zipkin-tracer/zipkin_tracer_base'

describe Trace::ZipkinTracerBase do
  let(:span_id) { 'c3a555b04cf7e099' }
  let(:parent_id) { 'f0e71086411b1445' }
  let(:sampled) { true }
  let(:trace_id) { Trace::TraceId.new(span_id, nil, span_id, sampled, Trace::Flags::EMPTY) }
  let(:trace_id_with_parent) { Trace::TraceId.new(span_id, parent_id, span_id, sampled, Trace::Flags::EMPTY) }
  let(:rpc_name) { 'this_is_an_rpc' }
  let(:tracer) { described_class.new }
  let(:span_hash) { {
    name: rpc_name,
    traceId: span_id,
    id: span_id,
    annotations: [],
    binaryAnnotations: [],
    timestamp: 1452987900000000,
    duration: 0,
    debug: false
  } }
  before { Timecop.freeze(Time.utc(2016, 1, 16, 23, 45, 0)) }

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
    context "no parentId" do
      it 'returns an empty span' do
        expect(span.binary_annotations).to eq([])
        expect(span.annotations).to eq([])
        expect(span.to_h).to eq(span_hash)
      end
    end
    context "with parentId" do
      let(:span) { tracer.start_span(trace_id_with_parent, rpc_name) }
      it 'returns an empty span' do
        expect(span.binary_annotations).to eq([])
        expect(span.annotations).to eq([])
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
    before { allow(Trace).to receive(:default_endpoint).and_return(Trace::Endpoint.new('127.0.0.1', '80', 'service_name')) }
    it 'closes the span' do
      span #touch it so it happens before we freeze time again
      Timecop.freeze(Time.utc(2016, 1, 16, 23, 45, 1))
      tracer.end_span(span)
      expect(span.to_h).to eq(span_hash.merge(duration: 1_000_000))
    end
    it 'flush if SS is annotated in this span' do
      span.record(Trace::Annotation::SERVER_SEND)
      expect(tracer).to receive(:flush!)
      expect(tracer).to receive(:reset)
      tracer.end_span(span)
    end
    it "does not flush if SS has not been annotated" do
      span.record(Trace::Annotation::SERVER_RECV)
      expect(tracer).not_to receive(:flush!)
      expect(tracer).not_to receive(:reset)
      tracer.end_span(span)
    end
  end

  describe '#with_new_span' do
    let(:result) { 'result' }
    it 'returns the value of the block' do
      expect(tracer.with_new_span(trace_id, rpc_name) { result }).to eq(result)
    end

    it "yields the span to the block" do
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
