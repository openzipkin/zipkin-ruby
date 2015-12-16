require 'spec_helper'
require 'zipkin-tracer/zipkin_kafka_tracer'

# needed the if statement because rspec tags are broken
if RUBY_PLATFORM == 'java'
  describe Trace::ZipkinKafkaTracer, :platform => :java do
    let(:id)   { double('id') }
    let(:span) { double('span') }
    let(:tracer) { described_class.new }
    let(:zookeepers) { 'localhost:2181'     }
    let(:zk)         { double('broker_ids') }
    let(:producer)   { double('producer')   }

    before do
      allow(Hermann::Discovery::Zookeeper).to receive(:new) { zk }
      allow(zk).to receive(:get_brokers)
      allow(Hermann::Producer).to receive(:new) { producer }
    end

    describe '#initialize' do
      context 'with default settings' do


        it 'has default topic' do
          expect(tracer.instance_variable_get(:@topic)).to eq Trace::ZipkinKafkaTracer::DEFAULT_KAFKA_TOPIC
        end
        it 'initializes instance variables' do
          expect(tracer.instance_variable_get(:@spans)).to be_a(Hash)
          expect(tracer.instance_variable_get(:@spans).length).to eq 0
        end
        it 'connects to zookeeper to create the producer' do
          expect(tracer.instance_variable_get(:@producer)).to eq producer
        end
      end

      context 'with options' do
        let(:topic)  { 'topic' }
        let(:traces_buffer) { 42 }

        let(:tracer) { described_class.new({traces_buffer: traces_buffer, topic: topic}) }

        it 'has an optional topic' do
          expect(tracer.instance_variable_get(:@topic)).to eq topic
        end
        it 'has an optional traces_buffer' do
          expect(tracer.instance_variable_get(:@traces_buffer)).to eq traces_buffer
        end
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
        expect(tracer).to_not receive(:get_span_for_id)
        tracer.record(id, annotation)
      end

      context 'processing annotation' do
        before do
          allow(id).to receive(:sampled?) { true }
          allow(tracer).to receive(:get_span_for_id) { span }
          expect(tracer).to receive(:flush!)
        end

        it 'records a binary annotation' do
          expect(span).to receive(:binary_annotations) { [] }
          tracer.record(id, binary_annotation)
        end
        it 'records an annotation' do
          expect(span).to receive(:annotations) { [] }
          tracer.record(id, annotation)
        end
      end
    end

    describe '#set_rpc_name' do
      let(:name) { 'name' }

      it 'returns if id already sampled' do
        allow(id).to receive(:sampled?) { false }
        expect(tracer).to_not receive(:get_span_for_id)
        tracer.set_rpc_name(id, name)
      end

      it 'sets the span name' do
        allow(id).to receive(:sampled?) { true }
        allow(tracer).to receive(:get_span_for_id) { span }
        expect(span).to receive(:name=).with(name)
        tracer.set_rpc_name(id, name)
      end
    end
  end
end
