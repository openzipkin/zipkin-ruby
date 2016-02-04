require 'spec_helper'
require 'zipkin-tracer/zipkin_null_tracer'

describe ZipkinTracer::TraceClient do
  let(:lc_value) { 'lc_value' }
  let(:key) { 'key' }
  let(:value) { 'value' }
  let(:result) { 'result' }
  subject { ZipkinTracer::TraceClient }

  before do
    Trace.tracer = Trace::NullTracer.new
    allow(Trace).to receive(:default_endpoint).and_return(Trace::Endpoint.new('127.0.0.1', '80', 'service_name'))
    allow(Trace.id).to receive(:next_id).and_return(Trace::TraceId.new(1, 2, 3, true, ::Trace::Flags::DEBUG))
  end

  def expect_new_span
    expect(Trace.tracer).to receive(:with_new_span).ordered.with(anything, 'lc').and_call_original
  end

  def expect_local_componant
    expect_any_instance_of(Trace::Span).to receive(:record).with(instance_of(Trace::BinaryAnnotation)) do |_, ann|
      expect(ann.key).to eq('lc')
      expect(ann.value).to eq(lc_value)
    end
  end

  describe '#record' do
    it 'records an annotation' do
      expect_new_span

      expect_any_instance_of(Trace::Span).to receive(:record).with(instance_of(Trace::Annotation)) do |_, ann|
        expect(ann.value).to eq('value')
      end

      expect_local_componant

      subject.local_component_span(lc_value) do |ztc|
        ztc.record(value)
      end
    end
  end

  describe '#record_tag' do
    it 'records a binary annotation' do
      expect_new_span

      expect_any_instance_of(Trace::Span).to receive(:record).with(instance_of(Trace::BinaryAnnotation)) do |_, ann|
        expect(ann.key).to eq('key')
        expect(ann.value).to eq('value')
      end

      expect_local_componant

      subject.local_component_span(lc_value) do |ztc|
        ztc.record_tag(key, value)
      end
    end
  end

  describe '#record_local_component' do
    it 'records a binary annotation ' do
      expect_new_span

      expect_any_instance_of(Trace::Span).to receive(:record).with(instance_of(Trace::BinaryAnnotation)) do |_, ann|
        expect(ann.key).to eq('lc')
        expect(ann.value).to eq('value')
      end

      expect_local_componant

      subject.local_component_span(lc_value) do |ztc|
        ztc.record_local_component(value)
      end
    end
  end

  describe '.local_component_span' do
    context 'called with block' do
      it 'creates new span' do
        expect_new_span
        expect_local_componant

        subject.local_component_span(lc_value) {}
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
      allow(Trace.id).to receive(:next_id).and_return(Trace::TraceId.new(1, 2, 3, false, 0))
    end

    it 'does not record annotations' do
      expect_new_span

      expect_any_instance_of(Trace::Span).not_to receive(:record)

      subject.local_component_span(lc_value) do |ztc|
        ztc.record(value)
      end
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
