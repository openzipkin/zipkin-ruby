require 'spec_helper'
require 'zipkin-tracer/zipkin_http_sender'

describe Trace::ZipkinHttpSender do
  let(:span_id) { ZipkinTracer::TraceGenerator.new.generate_id }
  let(:trace_id) { Trace::TraceId.new(span_id, nil, span_id, true, Trace::Flags::EMPTY) }
  let(:json_api_host) { 'http://json.example.com' }
  let(:logger) { Logger.new(nil) }
  let(:tracer) { described_class.new(json_api_host: json_api_host, logger: logger) }

  describe '#initialize' do
    it 'sets the SuckerPunch logger' do
      expect(SuckerPunch).to receive(:logger=).with(logger)
      tracer
    end
  end

  describe "#flush!" do
    before do
      Timecop.freeze
      stub_request(:post, /json.example.com/).to_return(status: 200)
    end

    let(:name) { "test" }
    let(:span) { tracer.start_span(trace_id, name) }

    it "flushes the list of spans to API" do
      spans = ::ZipkinTracer::HostnameResolver.new.spans_with_ips([span], described_class::IP_FORMAT).map(&:to_h)
      expect_any_instance_of(Faraday::Connection).to receive(:post).and_call_original
      expect_any_instance_of(Faraday::Request).to receive(:body=).with(spans.to_json)
      tracer.end_span(span)
    end
  end
end
