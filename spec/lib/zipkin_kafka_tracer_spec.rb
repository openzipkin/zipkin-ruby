require 'spec_helper'

# needed the if statement because rspec tags are broken
if RUBY_PLATFORM == 'java'
  require 'zipkin-tracer/zipkin_kafka_tracer'

  describe Trace::ZipkinKafkaTracer, :platform => :java do
    let(:span_id) { 'c3a555b04cf7e099' }
    let(:parent_id) { 'f0e71086411b1445' }
    let(:sampled) { true }
    let(:trace_id) { Trace::TraceId.new(span_id, nil, span_id, sampled, Trace::Flags::EMPTY) }
    let(:name) { 'test' }
    let(:tracer) { described_class.new(:zookeepers => zookeepers) }
    let(:zookeepers) { 'localhost:2181'     }
    let(:zk)         { double('broker_ids') }
    let(:producer)   { double('producer')   }
    let(:span) { tracer.start_span(trace_id, name) }

    before do
      allow(Hermann::Discovery::Zookeeper).to receive(:new) { zk }
      allow(zk).to receive(:get_brokers)
      allow(Hermann::Producer).to receive(:new) { producer }
    end

    describe '#initialize' do
      context 'with default settings' do

        before do
          expect(Hermann::Discovery::Zookeeper).to receive(:new) { zk }
          expect(zk).to receive(:get_brokers)
          expect(Hermann::Producer).to receive(:new) { producer }
        end

        it 'has default topic' do
          expect(tracer.instance_variable_get(:@topic)).to eq Trace::ZipkinKafkaTracer::DEFAULT_KAFKA_TOPIC
        end

        it 'connects to zookeeper to create a Hermann producer' do
          expect(tracer.instance_variable_get(:@producer)).to eq producer
        end
      end

      context 'with options including a :topic' do
        let(:topic)  { 'topic' }

        let(:tracer) { described_class.new({ :zookeepers => zookeepers, topic: topic }) }

        it 'has an optional topic' do
          expect(tracer.instance_variable_get(:@topic)).to eq topic
        end
      end

      context 'with options including a :producer' do
        subject { described_class.new(:producer => mock_producer) }

        let(:mock_producer) { double('Kafka producer', :push => true) }

        it 'uses that producer' do
          expect(subject.instance_variable_get(:@producer)).to be mock_producer
        end

        context 'that does not respond_to? #push' do
          let(:mock_producer) { double('Kafka producer',) }

          it 'raises ArgumentError' do
            expect { subject }.to raise_error ArgumentError
          end
        end
      end

      context 'with options including neither a :producer or a :zookeepers' do
        subject { described_class.new }

        it 'raises ArgumentError' do
          expect { subject }.to raise_error ArgumentError
        end
      end
    end

  end
end
