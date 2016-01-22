require 'spec_helper'

module ZipkinTracer
  describe TraceClient do
    let(:key) { 'key' }
    let(:value) { 'value' }
    subject { TraceClient }

    before do
      allow(Trace).to receive(:default_endpoint).and_return(Trace::Endpoint.new('127.0.0.1', '80', 'service_name'))
    end

    describe '.record' do
      it 'records an annotation' do
        expect(Trace).to receive(:record).with(instance_of(Trace::Annotation))
        subject.record(key)
      end
    end

    describe '.record_tag' do
      it 'records a binary annotation' do
        expect(Trace).to receive(:record).with(instance_of(Trace::BinaryAnnotation))
        subject.record_tag(key, value)
      end
    end

    describe '.record_local_component' do
      it 'records a binary annotation ' do
        expect(Trace).to receive(:record).with(instance_of(Trace::BinaryAnnotation))
        subject.record_local_component(key)
      end
    end

    describe '.trace' do
      context 'called with block' do
        it 'records two binary annotations' do
          expect(Trace).to receive(:record).with(instance_of(Trace::Annotation)).exactly(2).times
          subject.trace {}
        end
      end

      context 'called without block' do
        it 'records no annotations' do
          expect(Trace).not_to receive(:record)
          subject.trace
        end
      end
    end
  end
end
