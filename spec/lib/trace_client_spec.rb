require 'spec_helper'
require 'zipkin-tracer/zipkin_null_tracer'

describe ZipkinTracer::TraceClient do
  let(:lc_value) { 'lc_value' }
  let(:result) { 'result' }
  subject { ZipkinTracer::TraceClient }

  before do
    Trace.tracer = Trace::NullTracer.new
    allow(Trace).to receive(:default_endpoint).and_return(Trace::Endpoint.new('127.0.0.1', '80', 'service_name'))
    allow(Trace.id).to receive(:next_id).and_return(Trace::TraceId.new(1, 2, 3, true, ::Trace::Flags::DEBUG))
  end

  describe '.local_component_span' do
    context 'called with block' do
      it 'creates new span' do
        expect(Trace.tracer).to receive(:with_new_span).ordered.with(anything, 'lc').and_call_original
        expect_any_instance_of(Trace::Span).to receive(:record_local_component).with('lc_value')

        subject.local_component_span(lc_value) do |ztc|
          ztc.record('value')
        end
      end

      it 'returns the result of block' do
        expect(subject.local_component_span(lc_value) { result } ).to eq('result')
      end
    end

    context 'called without block' do
      it 'raises argument error' do
        expect{ subject.local_component_span(lc_value) }.to raise_error(ArgumentError, 'no block given')
      end
    end
  end

  describe 'Trace has not been sampled' do
    before do
      allow(Trace.id).to receive(:next_id).and_return(Trace::TraceId.new(1, 2, 3, false, ::Trace::Flags::EMPTY))
    end

    it 'does not create new span' do
      expect(Trace.tracer).not_to receive(:with_new_span)

      subject.local_component_span(lc_value) do |ztc|
        ztc.record('value')
      end
    end

    it 'returns the result of block' do
      expect(subject.local_component_span(lc_value) { result } ).to eq('result')
    end
  end

  describe 'Local tracing spans are nesting' do
    it 'have same parent_id but different span_ids' do
      subject.local_component_span(lc_value) do |ztc|
        parent_local_trace = Trace.id
        subject.local_component_span(lc_value) do |ztc|
          expect(parent_local_trace.trace_id).to eq(Trace.id.trace_id)
          expect(parent_local_trace.span_id).not_to eq(Trace.id.span_id)
          expect(Trace.id.parent_id).to eq(parent_local_trace.span_id)
        end
      end
    end
  end
end
