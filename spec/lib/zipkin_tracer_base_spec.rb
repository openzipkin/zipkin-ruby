require 'spec_helper'
require 'zipkin-tracer/zipkin_tracer_base'

describe Trace::ZipkinTracerBase do
  let(:span_id) { 'c3a555b04cf7e099' }
  let(:parent_id) { 'f0e71086411b1445' }
  let(:sampled) { true }
  let(:trace_id) { Trace::TraceId.new(span_id, nil, span_id, sampled, Trace::Flags::EMPTY) }
  let(:rpc_name) { 'this_is_an_rpc' }
  let(:tracer) { described_class.new }
  let(:span_hash) { {
    name: rpc_name,
    traceId: span_id,
    id: span_id,
    parentId: nil,
    annotations: [],
    binaryAnnotations: [],
    timestamp: 1452987900000000,
    duration: 0,
    debug: false
  } }
  before { Timecop.freeze(Time.utc(2016, 1, 16, 23, 45)) }

  describe '#start_span' do
    let(:span) { tracer.start_span(trace_id, rpc_name) }
    let(:rpc_name) { 'this_is_an_rpc' }
    it 'sets the span name' do
      expect(span.name).to eq(rpc_name)
    end
    it 'returns an empty span' do
      expect(span.binary_annotations).to eq([])
      expect(span.annotations).to eq([])
      expect(span.to_h).to eq(span_hash)
    end
  end

  describe '#end_span' do
    let(:span) { tracer.start_span(trace_id, rpc_name) }
    it 'flush if SS is annotated in this span' do
      span.record(Trace::Annotation.new(Trace::Annotation::SERVER_SEND, Trace.default_endpoint))
      expect(tracer).to receive(:flush!)
      expect(tracer).to receive(:reset)
      tracer.end_span(span)
    end
    it "does not flush if SS has not been annotated" do
      span.record(Trace::Annotation.new(Trace::Annotation::SERVER_RECV, Trace.default_endpoint))
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
