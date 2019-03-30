# encoding: utf-8
# the magic comment above is needed for JRuby 1.x as we have multi byte chars in this file

require 'rack/mock'
require 'spec_helper'
require 'zipkin-tracer/zipkin_json_tracer'
require 'zipkin-tracer/zipkin_null_tracer'

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
  let(:tracer) { double('Trace::NullTracer') }

  before do
    allow(ZipkinTracer::Application).to receive(:logger).and_return(logger)
  end

  describe 'initializer' do
    # see spec/lib/zipkin_kafka_tracer_spec.rb
    if RUBY_PLATFORM == 'java'
      context 'configured to use kafka', platform: :java do
        require 'zipkin-tracer/zipkin_kafka_tracer'

        let(:zookeeper) { 'localhost:2181' }
        let(:zipkinKafkaTracer) { double('ZipkinKafkaTracer') }
        let(:config) { configuration(zookeeper: zookeeper) }

        it 'creates a zipkin kafka tracer' do
          allow(Trace::ZipkinKafkaTracer).to receive(:new) { tracer }
          expect(Trace).to receive(:tracer=).with(tracer)
          expect(described_class.new.tracer(config)).to eq(tracer)
        end
      end
    end

    context 'configured to use json' do
      let(:config) { configuration(json_api_host: 'fake_json_api_host') }

      it 'creates a zipkin json tracer' do
        allow(Trace::ZipkinJsonTracer).to receive(:new) { tracer }
        expect(Trace).to receive(:tracer=).with(tracer)
        expect(described_class.new.tracer(config)).to eq(tracer)
      end
    end

    context 'configured to use logger' do
      let(:config) { configuration(log_tracing: true) }

      it 'creates a logger tracer' do
        allow(Trace::ZipkinLoggerTracer).to receive(:new) { tracer }
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
          { zookeeper: "" }
        ].each do |options|
          config = configuration(options)
          allow(Trace::NullTracer).to receive(:new) { tracer }
          expect(Trace).to receive(:tracer=).with(tracer)
          expect(described_class.new.tracer(config)).to eq(tracer)
        end
      end
    end

  end
end
