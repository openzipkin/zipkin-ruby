require 'rack/mock'
require 'spec_helper'

describe ZipkinTracer::TracerFactory do
  def middleware(app, config={})
    configuration = { logger: logger, sample_rate: 1}.merge(config)
    described_class.new(app, configuration)
  end

   def configuration(options)
     ZipkinTracer::Config.new(nil, options)
   end

  let(:logger) { Logger.new(nil) }
  let(:subject) { described_class.new(config)}
  let(:tracer) { double('Trace::NullTracer') }


  describe 'initializer' do
    # see spec/lib/zipkin_kafka_tracer_spec.rb
    if RUBY_PLATFORM == 'java'
      context 'configured to use kafka', platform: :java do
        let(:zookeeper) { 'localhost:2181' }
        let(:zipkinKafkaTracer) { double('ZipkinKafkaTracer') }
        let(:config) { configuration({zookeeper: zookeeper}) }

        it 'creates a zipkin kafka tracer' do
          allow(::Trace::ZipkinKafkaTracer).to receive(:new) { tracer }
          expect(::Trace).to receive(:tracer=).with(tracer)
          described_class.new.tracer(config)
        end
      end
    end

    context 'configured to use json' do
      let(:config) { configuration({json_api_host: 'fake_json_api_host'}) }

      it 'creates a zipkin kafka tracer' do
        allow(::Trace::ZipkinJsonTracer).to receive(:new) { tracer }
        expect(::Trace).to receive(:tracer=).with(tracer)
        described_class.new.tracer(config)
      end
    end

    context 'configured to use scribe' do
      let(:config) { configuration({scribe_server: 'fake_scribe_server'}) }

      it 'creates a zipkin kafka tracer' do
        allow(::Trace::ZipkinTracer).to receive(:new) { tracer }
        expect(::Trace).to receive(:tracer=).with(tracer)
        described_class.new.tracer(config)
      end
    end

    context 'no transport configured' do
      let(:config) { configuration({}) }
      it 'creates a zipkin kafka tracer' do
        allow(Trace::NullTracer).to receive(:new) { tracer }
        expect(::Trace).to receive(:tracer=).with(tracer)
        described_class.new.tracer(config)
      end
    end

    context 'no domain environment variable' do
      let(:config) { configuration({service_name: 'zipkin-tester'}) }
      before do
        ENV['DOMAIN'] = ''
      end

      it 'sets the trace endpoint service name to the default configuration file value' do
        expect(::Trace::Endpoint).to receive(:make_endpoint).with(nil, anything, 'zipkin-tester', :i32)
        described_class.new.tracer(config)
      end
    end

    context 'domain environment variable initialized' do
      let(:config) { configuration({service_name: 'zipkin-tester'}) }
      before do
        ENV['DOMAIN'] = 'zipkin-env-var-tester.example.com'
      end

      it 'sets the trace endpoint service name to the environment variable value' do
        expect(::Trace::Endpoint).to receive(:make_endpoint).with(nil, anything, 'zipkin-env-var-tester', :i32)
        described_class.new.tracer(config)
      end
    end
  end
end
