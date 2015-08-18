require 'spec_helper'

# needed the if statement because rspec tags are broken
if RUBY_PLATFORM == 'java'
  describe Trace::ZipkinKafkaTracer, :platform => :java do
    let(:id)   { double('id') }
    let(:span) { double('span') }

    describe '#initialize' do
      context 'with default settings' do
        it 'has nil logger' do
          expect(subject.instance_variable_get(:@logger)).to be nil
        end
        it 'has default topic' do
          expect(subject.instance_variable_get(:@topic)).to eq Trace::ZipkinKafkaTracer::DEFAULT_KAFKA_TOPIC
        end
        it 'initializes instance variables' do
          expect(subject.instance_variable_get(:@spans)).to be_a(Hash)
          expect(subject.instance_variable_get(:@spans).length).to eq 0
        end
      end

      context 'with options' do
        let(:logger) { double('logger') }
        let(:topic)  { 'topic' }

        subject { described_class.new({:logger => logger, :topic => topic}) }

        it 'has logger' do
          expect(subject.instance_variable_get(:@logger)).to be logger
        end
        it 'has an optional topic' do
          expect(subject.instance_variable_get(:@topic)).to eq topic
        end
      end
    end

    describe '#connect' do
      let(:zookeepers) { 'localhost:2181'     }
      let(:zk)         { double('broker_ids') }
      let(:producer)   { double('producer')   }

      it 'connects to zookeeper to create the producer' do
        allow(Hermann::Discovery::Zookeeper).to receive(:new) { zk }
        allow(zk).to receive(:get_brokers)
        allow(Hermann::Producer).to receive(:new) { producer }
        subject.connect(zookeepers)
        expect(subject.instance_variable_get(:@producer)).to eq producer
      end
    end

    describe '#record' do
      module MockTrace
        class BinaryAnnotation < Trace::BinaryAnnotation
          def initialize;end
        end
        class Annotation < Trace::Annotation
          def initialize;end
        end
      end

      let(:binary_annotation) { MockTrace::BinaryAnnotation.new }
      let(:annotation)        { MockTrace::Annotation.new }

      it 'returns if id already sampled' do
        allow(id).to receive(:sampled?) { false }
        expect(subject).to_not receive(:get_span_for_id)
        subject.record(id, annotation)
      end

      context 'processing annotation' do
        before do
          allow(id).to receive(:sampled?) { true }
          allow(subject).to receive(:get_span_for_id) { span }
          expect(subject).to receive(:flush!)
        end

        it 'records a binary annotation' do
          expect(span).to receive(:binary_annotations) { [] }
          subject.record(id, binary_annotation)
        end
        it 'records an annotation' do
          expect(span).to receive(:annotations) { [] }
          subject.record(id, annotation)
        end
      end
    end

    describe '#set_rpc_name' do
      let(:name) { 'name' }

      it 'returns if id already sampled' do
        allow(id).to receive(:sampled?) { false }
        expect(subject).to_not receive(:get_span_for_id)
        subject.set_rpc_name(id, name)
      end

      it 'sets the span name' do
        allow(id).to receive(:sampled?) { true }
        allow(subject).to receive(:get_span_for_id) { span }
        expect(span).to receive(:name=).with(name)
        subject.set_rpc_name(id, name)
      end
    end
  end
end
