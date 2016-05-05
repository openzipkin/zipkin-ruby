require 'spec_helper'
require 'securerandom'
require 'zipkin-tracer/zipkin_logger_tracer'

describe Trace::ZipkinLoggerTracer do
  let(:span_id) { Trace.generate_id }
  let(:trace_id) { Trace::TraceId.new(span_id, nil, span_id, true, Trace::Flags::EMPTY) }
  let(:name) { 'trusmis' }
  let(:logger) { Logger.new(nil) }

  describe '#flush!' do
    it 'flushes the list of spans into the log' do
      tracer = described_class.new(logger: logger)
      the_span = nil
      tracer.with_new_span(trace_id, name) do |span|
        the_span = span
        span.record_tag('test', 'prueba')
      end
      spans = ::ZipkinTracer::HostnameResolver.new.spans_with_ips([the_span]).map(&:to_h)
      log_text = { described_class::TRACING_KEY => spans }.to_json
      expect(logger).to receive(:info).with(log_text)
      tracer.flush!
    end
  end
end
