require 'spec_helper'
require 'zipkin-tracer/zipkin_null_tracer'

describe ZipkinTracer::TraceClient do
  let(:lc_value) { 'lc_value' }
  let(:result) { 'result' }
  subject { ZipkinTracer::TraceClient }

  before do
    Trace.tracer = Trace::NullTracer.new
    allow(Trace).to receive(:default_endpoint).and_return(Trace::Endpoint.new('127.0.0.1', '80', 'service_name'))
    Trace.sample_rate = 1
    ZipkinTracer::TraceContainer.cleanup!
  end

  describe '.local_component_span' do
    context 'called with block' do
      it 'creates new span' do
        expect(Trace.tracer).to receive(:with_new_span).ordered.with(anything, 'lc_value').and_call_original
        expect_any_instance_of(Trace::Span).to receive(:record_tag).with('lc', 'lc_value')

        subject.local_component_span(lc_value) do |ztc|
          ztc.record('value')
        end
      end

      it 'returns the result of block' do
        expect(subject.local_component_span(lc_value) { result }).to eq('result')
      end
    end

    context 'called without block' do
      it 'raises argument error' do
        expect { subject.local_component_span(lc_value) }.to raise_error(ArgumentError, 'no block given')
      end
    end
  end

  describe 'Trace has not been sampled' do
    before do
      Trace.sample_rate = 0
    end

    it 'does not create new span' do
      expect(ZipkinTracer::TraceContainer).not_to receive(:with_new_span)

      subject.local_component_span(lc_value) do |ztc|
        ztc.record('value')
      end
    end

    it 'returns the result of block' do
      expect(subject.local_component_span(lc_value) { result }).to eq('result')
    end
  end

  describe 'Local tracing spans are nesting' do
    it 'have same parent_id but different span_ids' do
      subject.local_component_span(lc_value) do |_ztc|
        parent_local_trace = ZipkinTracer::TraceContainer.current
        subject.local_component_span(lc_value) do |__ztc|
          new_current = ZipkinTracer::TraceContainer.current
          expect(parent_local_trace.trace_id).to eq(new_current.trace_id)
          expect(parent_local_trace.span_id).not_to eq(new_current.span_id)
          expect(new_current.parent_id).to eq(parent_local_trace.span_id)
        end
      end
    end
  end
end
