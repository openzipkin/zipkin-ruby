require 'spec_helper'
require 'securerandom'
require 'zipkin-tracer/zipkin_logger_tracer'

describe Trace::ZipkinLoggerTracer do
  let(:span_id) { ZipkinTracer::TraceGenerator.new.generate_id }
  let(:trace_id) { Trace::TraceId.new(span_id, nil, span_id, true, Trace::Flags::EMPTY) }
  let(:name) { 'trusmis' }
  let(:logger) { Logger.new(nil) }
  let(:tracer) { described_class.new(logger: logger) }
  let(:span) { tracer.start_span(trace_id, name) }

  describe '#flush!' do
    before { Timecop.freeze }

    it 'flushes the list of spans into the log' do
      span.record_tag('test', 'prueba')
      spans = ::ZipkinTracer::HostnameResolver.new.spans_with_ips([span], described_class::IP_FORMAT).map(&:to_h)
      log_text = { described_class::TRACING_KEY => spans }.to_json
      expect(logger).to receive(:info).with(log_text)

      tracer.end_span(span)
    end
  end
end
