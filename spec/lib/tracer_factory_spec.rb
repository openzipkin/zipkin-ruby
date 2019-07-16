# encoding: utf-8
# the magic comment above is needed for JRuby 1.x as we have multi byte chars in this file

require 'rack/mock'
require 'spec_helper'
require 'zipkin-tracer/zipkin_http_sender'
require 'zipkin-tracer/zipkin_null_sender'
require 'zipkin-tracer/zipkin_rabbit_mq_sender'

describe ZipkinTracer::TracerFactory do
  def middleware(app, config={})
    configuration = { logger: logger, sample_rate: 1 }.merge(config)
    described_class.new(app, configuration)
  end

   def configuration(options)
     ZipkinTracer::Config.new(nil, options)
   end

  let(:logger) { Logger.new(nil) }
  let(:subject) { described_class.new(config) }
  let(:tracer) { double('Trace::NullSender') }

  before do
    allow(ZipkinTracer::Application).to receive(:logger).and_return(logger)
  end

  describe 'initializer' do
    # see spec/lib/zipkin_kafka_sender_spec.rb
    if RUBY_PLATFORM == 'java'
      context 'configured to use kafka', platform: :java do
        require 'zipkin-tracer/zipkin_kafka_sender'

        let(:zookeeper) { 'localhost:2181' }
        let(:config) { configuration(zookeeper: zookeeper) }

        it 'creates a zipkin kafka sender' do
          allow(Trace::ZipkinKafkaSender).to receive(:new) { tracer }
          expect(Trace).to receive(:tracer=).with(tracer)
          expect(described_class.new.tracer(config)).to eq(tracer)
        end
      end
    end

    context 'configured to use json' do
      let(:config) { configuration(json_api_host: 'fake_json_api_host') }

      it 'creates a zipkin json tracer' do
        allow(Trace::ZipkinHttpSender).to receive(:new) { tracer }
        expect(Trace).to receive(:tracer=).with(tracer)
        expect(described_class.new.tracer(config)).to eq(tracer)
      end
    end

    context 'configured to use logger' do
      let(:config) { configuration(log_tracing: true) }

      it 'creates a logger tracer' do
        allow(Trace::ZipkinLoggerSender).to receive(:new) { tracer }
        expect(Trace).to receive(:tracer=).with(tracer)
        expect(described_class.new.tracer(config)).to eq(tracer)
      end
    end

    context 'configured to use Amazon SQS' do
      let(:config) { configuration(sqs_queue_name: 'zipkin-sqs') }

      it 'creates a sqs tracer' do
        allow(Trace::ZipkinSqsSender).to receive(:new) { tracer }
        expect(Trace).to receive(:tracer=).with(tracer)
        expect(described_class.new.tracer(config)).to eq(tracer)
      end
    end

    context 'configured to use RabbitMQ' do
      let(:connection) { double('RabbitMQ connection', create_channel: {}) }
      let(:config) { configuration(rabbit_mq_connection: connection) }

      it 'creates a rabbit mq tracer' do
        allow(Trace::ZipkinRabbitMqSender).to receive(:new) { tracer }
        expect(Trace).to receive(:tracer=).with(tracer)
        expect(described_class.new.tracer(config)).to eq(tracer)
      end
    end

    context 'no transport configured' do
      it 'creates a null tracer' do
        [
          {},
          { json_api_host: nil },
          { json_api_host: "" },
          { json_api_host: "\n\t 　\r" },
          { zookeeper: "" },
          { sqs_queue_name: "" }
        ].each do |options|
          config = configuration(options)
          allow(Trace::NullSender).to receive(:new) { tracer }
          expect(Trace).to receive(:tracer=).with(tracer)
          expect(described_class.new.tracer(config)).to eq(tracer)
        end
      end
    end

  end
end
