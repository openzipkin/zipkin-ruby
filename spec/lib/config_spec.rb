require 'spec_helper'

module ZipkinTracer
  RSpec.describe Config do
    before do
      allow(Application).to receive(:logger).and_return(Logger.new(nil))
    end
    [:service_name, :json_api_host,
      :zookeeper, :log_tracing,
      :annotate_plugin, :filter_plugin, :whitelist_plugin].each do |method|
      it "can set and read configuration values for #{method}" do
        value = rand(100)
        config = Config.new(nil, { method => value })
        expect(config.send(method)).to eq(value)
      end
      it 'can set a sample rate between 0 and 1' do
        config = Config.new(nil, sample_rate: 0.3)
        expect(config.sample_rate).to eq(0.3)
      end
    end

    it 'sets defaults' do
      config = Config.new(nil, {})
      [:sample_rate, :sampled_as_boolean, :trace_id_128bit].each do |key|
        expect(config.send(key)).to_not eq(nil)
      end
    end

    describe 'logger' do
      it 'uses the application logger' do
        config = Config.new(nil, {})
        expect(config.logger).to eq(Application.logger)
      end
    end

    describe 'sampled_as_boolean' do
      it 'does not warn when sampled_as_boolean is false' do
        expect(Application.logger).to_not receive(:warn)
        Config.new(nil, {sampled_as_boolean: false})
      end

      it 'warns when sampled_as_boolean is not set' do
        expect(Application.logger).to receive(:warn)
        Config.new(nil, {})
      end

      it 'warns when sampled_as_boolean is true' do
        expect(Application.logger).to receive(:warn)
        Config.new(nil, {sampled_as_boolean: true})
      end
    end

    describe '#adapter' do
      it 'returns nil if no adapter has been set' do
        config = Config.new(nil, {})
        expect(config.adapter).to be_nil
      end

      context 'json' do
        it 'returns :json if the json api endpoint has been set' do
          config = Config.new(nil, json_api_host: 'http://server.yes.net')
          expect(config.adapter).to eq(:json)
        end
      end

      context 'log_tracing' do
        it 'returns :logger if log_tracing has been set to true' do
          config = Config.new(nil, log_tracing: true)
          expect(config.adapter).to eq(:logger)
        end
      end

      context 'kafka' do
        before { stub_const('RUBY_PLATFORM', 'java') }

        it 'does not return :kafka if zookeeper has not been set' do
          config = Config.new(nil, {})
          stub_const('Hermann', 'CoolGem')
          expect(config.adapter).to be_nil
        end

        it 'returns :kafka if zookeeper and Hermann are used in java' do
          stub_const('Hermann', 'CoolGem')
          config = Config.new(nil, zookeeper: 'http://server.yes.net')
          expect(config.adapter).to eq(:kafka)
        end

        it 'returns :kafka_producer if producer is set' do
          producer = double("Producer", push: true)
          config = Config.new(nil, producer: producer)
          expect(config.adapter).to eq(:kafka_producer)
        end
      end

      context 'sqs' do
        context 'Aws::SQS is defined' do
          it 'returns :sqs if sqs_queue_name has been set' do
            config = Config.new(nil, sqs_queue_name: 'zipkin-sqs')
            expect(config.adapter).to eq(:sqs)
          end
        end

        context 'Aws::SQS is not defined' do
          before { hide_const('Aws::SQS') }

          it 'does not return :sqs' do
            config = Config.new(nil, sqs_queue_name: 'zipkin-sqs')
            expect(config.adapter).to eq(nil)
          end
        end
      end

      context 'no domain environment variable' do
        before do
          ENV['DOMAIN'] = ''
        end

        it 'sets the trace endpoint service name to the default configuration file value' do
          expect(Trace::Endpoint).to receive(:local_endpoint).with('zipkin-tester') { 'endpoint' }
          expect(Trace).to receive(:default_endpoint=).with('endpoint')
          Config.new(nil, service_name: 'zipkin-tester')
        end

        context 'json adapter' do
          let(:config) { { service_name: 'zipkin-tester', json_api_host: 'host' } }
          it 'calls with string ip format' do
            expect(Trace::Endpoint).to receive(:local_endpoint).with('zipkin-tester') { 'endpoint' }
            expect(Trace).to receive(:default_endpoint=).with('endpoint')
            Config.new(nil, config)
          end
        end
      end

      context 'domain environment variable initialized' do
        let(:config) { { service_name: 'zipkin-tester' } }
        before do
          ENV['DOMAIN'] = 'zipkin-env-var-tester.example.com'
        end

        it 'sets the trace endpoint service name to the environment variable value' do
          expect(Trace::Endpoint).to receive(:local_endpoint).with('zipkin-env-var-tester') { 'endpoint' }
          expect(Trace).to receive(:default_endpoint=).with('endpoint')
          Config.new(nil, config)
        end
      end
    end
  end
end
