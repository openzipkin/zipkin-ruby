require 'spec_helper'

module ZipkinTracer
  RSpec.describe Config do
    [:service_name, :service_port, :json_api_host, :traces_buffer,
      :scribe_server, :zookeeper, :sample_rate, :scribe_max_buffer,
      :annotate_plugin, :filter_plugin, :whitelist_plugin, :logger].each do |method|
      it "can set and read configuration values for #{method}" do
        value = rand(100)
        config = Config.new(nil, { method => value })
        expect(config.send(method)).to eq(value)
      end
    end

    it 'sets defaults' do
      config = Config.new(nil, {})
      [:traces_buffer,:sample_rate, :scribe_max_buffer, :service_port].each do |key|
        expect(config.send(key)).to_not eq(nil)
      end
    end

    describe 'logger' do
      it 'uses Rails logger if available' do
        logger = 'TrusmisLogger'
        object_double("Rails", logger: logger).as_stubbed_const

        config = Config.new(nil, {})
        expect(config.logger).to eq(logger)
      end

      it 'uses STDOUT if nothing was provided and not using rails' do
        config = Config.new(nil, {})
        expect(config.logger).to be_kind_of(Logger)
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

      context 'scribe' do
        it 'does not return :scribe if Scribe is not in the project' do
          hide_const('Scribe')
          config = Config.new(nil, scribe_server: 'http://server.yes.net')
          expect(config.adapter).to be_nil
        end

        it 'returns :scribe if the scribe server has been set' do
          require 'scribe'
          config = Config.new(nil, scribe_server: 'http://server.yes.net')
          expect(config.adapter).to eq(:scribe)
        end
      end

      context 'kafka' do
        before { stub_const('RUBY_PLATFORM', 'java') }

        it 'does not return :kafka if zookeeper has not been set' do
          config = Config.new(nil, {})
          stub_const('Hermann', 'CoolGem')
          expect(config.adapter).to be_nil
        end

        it 'does not return :kafka if Hermann is not in the project' do
          hide_const('Hermann')
          config = Config.new(nil, zookeeper: 'http://server.yes.net')
          expect(config.adapter).to be_nil
        end

        it 'returns :kafka if zookeeper and Hermann are used in java' do
          stub_const('Hermann', 'CoolGem')
          config = Config.new(nil, zookeeper: 'http://server.yes.net')
          expect(config.adapter).to eq(:kafka)
        end
      end
    end
  end
end
