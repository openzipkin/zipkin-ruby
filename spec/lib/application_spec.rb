require 'spec_helper'
module ZipkinTracer
  RSpec.describe Application do
    describe '.routable_request?' do
      it 'returns rails routable information if available' do
        stub_const("Rails", Class.new)
        allow(Rails).to receive_message_chain("application.routes.recognize_path") { nil }
        expect(Application.routable_request?("path")).to eq(true)
      end
      it 'returns true when Rails not available' do
        expect(Application.routable_request?("path")).to eq(true)
      end
    end

    describe '.logger' do
      it 'returns rails logger if available' do
        stub_const("Rails", Class.new)
        expect(Rails).to receive(:logger)
        Application.logger
      end
      it 'returns standard logger if there is no Rails logger' do
        expect(Logger).to receive(:new).with(STDOUT)
        Application.logger
      end
    end

    describe '.config' do
      it 'returns empty hash if no config' do
        expect(Application.config(nil)).to eq({})
      end
      it 'returns config if available' do
        app = double('application')
        config = { config: true }
        allow(app).to receive_message_chain("config.zipkin_tracer") { config }
        expect(Application.config(app)).to eq(config)
      end
    end
  end
end
