require 'spec_helper'
require 'zipkin-tracer/zipkin_json_tracer'

describe Trace::ZipkinJsonTracer do
  let(:json_api_host) { 'http://json.example.com' }
  let(:default_options) { { json_api_host: json_api_host } }

  describe '#initialize' do
    let(:logger) { nil }
    it 'sets the SuckerPunch logger' do
      expect(SuckerPunch).to receive(:logger=).with(logger)
      described_class.new(default_options.merge(logger: logger))
    end
  end

end
