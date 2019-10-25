require 'spec_helper'

describe ZipkinTracer::B3HeaderHelper do
  class MockHandler
    include ZipkinTracer::B3HeaderHelper

    def call(headers, trace_id)
      set_b3_header(headers, trace_id)
    end
  end

  let(:parent_id) { 2 }
  let(:trace_id) { ::Trace::TraceId.new(1, parent_id, 3, true, ::Trace::Flags::DEBUG) }
  let(:write_b3_single_format) { false }
  before { allow(Trace).to receive(:write_b3_single_format).and_return(write_b3_single_format) }

  context 'child span' do
    context 'write_b3_single_format is false' do
      it 'has ParentSpanId header' do
        request_headers = {}
        MockHandler.new.call(request_headers, trace_id)

        expect(request_headers['X-B3-TraceId']).to eq('0000000000000001')
        expect(request_headers['X-B3-ParentSpanId']).to eq('0000000000000002')
        expect(request_headers['X-B3-SpanId']).to eq('0000000000000003')
        expect(request_headers['X-B3-Sampled']).to eq('true')
        expect(request_headers['X-B3-Flags']).to eq('1')
      end
    end

    context 'write_b3_single_format is true' do
      let(:write_b3_single_format) { true }

      it 'has parent id part' do
        request_headers = {}
        MockHandler.new.call(request_headers, trace_id)

        expect(request_headers['b3']).to eq('0000000000000001-0000000000000003-d-0000000000000002')
      end
    end
  end

  context 'root span' do
    let(:parent_id) { nil }

    context 'write_b3_single_format is false' do
      it 'omits ParentSpanId header' do
        request_headers = {}
        MockHandler.new.call(request_headers, trace_id)

        expect(request_headers).not_to have_key('X-B3-ParentSpanId')

        expect(request_headers['X-B3-TraceId']).to eq('0000000000000001')
        expect(request_headers['X-B3-SpanId']).to eq('0000000000000003')
        expect(request_headers['X-B3-Sampled']).to eq('true')
        expect(request_headers['X-B3-Flags']).to eq('1')
      end
    end

    context 'write_b3_single_format is true' do
      let(:write_b3_single_format) { true }

      it 'does not have parent id part' do
        request_headers = {}
        MockHandler.new.call(request_headers, trace_id)

        expect(request_headers['b3']).to eq('0000000000000001-0000000000000003-d')
      end
    end
  end
end
