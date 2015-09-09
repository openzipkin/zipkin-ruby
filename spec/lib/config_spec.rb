require 'spec_helper'
def using_scribe?
  @scribe_server && defined?(::Scribe)
end

def using_kafka?
  @zookeeper && RUBY_PLATFORM == 'java' && defined?(::Hermann)
end

module ZipkinTracer
  RSpec.describe Config do
    [:service_name, :service_port, :scribe_server, :zookeeper, :sample_rate,
      :scribe_max_buffer, :annotate_plugin, :filter_plugin, :whitelist_plugin].each do |method|
      it "can set and read configuration values for #{method}" do
        value = rand(100)
        config = Config.new(nil, {method => value})
        expect(config.send(method)).to eq(value)
      end
    end

    it 'sets defaults for sample rate' do
      config = Config.new(nil, {})
      expect(config.sample_rate).to_not eq(nil)
    end

    it 'sets defaults for scribe_max_buffer' do
      config = Config.new(nil, {})
      expect(config.scribe_max_buffer).to_not eq(nil)
    end

    describe '#using_scribe?' do
      it 'returns false if scribe server has not been set' do
        config = Config.new(nil, {})
        expect(config.using_scribe?).to eq(false)
      end
      it 'returns false if Scribe is not in the project' do
        hide_const('Scribe')
        config = Config.new(nil, {scribe_server: 'http://server.yes.net'})
        expect(config.using_scribe?).to eq(false)
      end
      it 'returns true if scribe server has been set' do
        config = Config.new(nil, {scribe_server: 'http://server.yes.net'})
        expect(config.using_scribe?).to eq(true)
      end
    end

    def using_kafka?
      @zookeeper && RUBY_PLATFORM == 'java' && defined?(::Hermann)
    end

    describe '#using_kafka?' do
      it 'returns false if zookeeper has not been set' do
        config = Config.new(nil, {})
        stub_const('Hermann', 'CoolGem')
        stub_const('RUBY_PLATFORM', 'java')
        expect(config.using_scribe?).to eq(false)
      end
      it 'returns false if Hermann is not in the project' do
        hide_const('Hermann')
        stub_const('RUBY_PLATFORM', 'java')
        config = Config.new(nil, {zookeeper: 'http://server.yes.net'})
        expect(config.using_scribe?).to eq(false)
      end
      it 'returns true if zookeeper and herman are used in java' do
        stub_const('Hermann', 'CoolGem')
        stub_const('RUBY_PLATFORM', 'java')
        config = Config.new(nil, {zookeeper: 'http://server.yes.net'})
        expect(config.using_kafka?).to eq(true)
      end
    end
  end
end
