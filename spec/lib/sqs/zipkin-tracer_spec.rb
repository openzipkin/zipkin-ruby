require 'spec_helper'
require 'zipkin-tracer/sqs/zipkin-tracer'
require 'zipkin-tracer/zipkin_null_sender'

describe ZipkinTracer::SqsHandler do
  class FakeSqsClient
    def send_message(params = {}, options = {})
      [params, options]
    end

    def send_message_batch(params = {}, options = {})
      [params, options]
    end
  end

  FakeSqsClient.prepend(ZipkinTracer::SqsHandler)

  let(:tracer) { Trace::NullSender.new }
  let(:span_id) { ZipkinTracer::TraceGenerator.new.generate_id }
  let(:trace_id) { Trace::TraceId.new(span_id, nil, span_id, sampled, Trace::Flags::EMPTY) }
  let(:remote_endpoint) { Trace::Endpoint.remote_endpoint(nil, 'amazon-sqs') }
  let(:queue_url) { 'http://sqs.com' }
  let(:message_attributes) do
    {
      trace_id: {
        data_type: 'String',
        string_value: trace_id.trace_id.to_s
      },
      span_id: {
        data_type: 'String',
        string_value: trace_id.span_id.to_s
      },
      sampled: {
        data_type: 'String',
        string_value: sampled
      }
    }
  end

  before do
    allow(Trace).to receive(:tracer).and_return(tracer)
    allow_any_instance_of(ZipkinTracer::TraceGenerator).to receive(:next_trace_id).and_return(trace_id)
  end

  shared_examples_for 'add trace data' do |method_name|
    context 'sampled' do
      let(:sampled) { 'true' }

      it 'generates a new span and adds trace data to the sqs message' do
        expect(ZipkinTracer::TraceContainer).to receive(:with_trace_id).ordered.once.and_call_original
        expect(tracer).to receive(:with_new_span).ordered.with(trace_id, method_name).and_call_original
        expect_any_instance_of(Trace::Span).to receive(:kind=).with(Trace::Span::Kind::PRODUCER)
        expect_any_instance_of(Trace::Span).to receive(:remote_endpoint=).with(remote_endpoint)
        expect_any_instance_of(Trace::Span).to receive(:record_tag).with('queue.url', queue_url)
        expect(FakeSqsClient.new.send(method_name, params)).to eq([expected_params, {}])
      end
    end

    context 'not sampled' do
      let(:sampled) { 'false' }

      it 'does not generate a new span but adds trace data to the sqs message' do
        expect(ZipkinTracer::TraceContainer).to receive(:with_trace_id).ordered.once.and_call_original
        expect(tracer).not_to receive(:with_new_span)
        expect_any_instance_of(Trace::Span).not_to receive(:kind=)
        expect(FakeSqsClient.new.send(method_name, params)).to eq([expected_params, {}])
      end
    end
  end

  describe '#send_message' do
    include_examples 'add trace data', :send_message do
      let(:params) { { queue_url: queue_url, message_body: 'test' } }
      let(:expected_params) { { queue_url: queue_url, message_body: 'test', message_attributes: message_attributes } }
    end
  end

  describe '#send_message_batch' do
    include_examples 'add trace data', :send_message_batch do
      let(:params) do
        {
          queue_url: queue_url,
          entries: [
            { id: 'msg1', message_body: 'test' },
            { id: 'msg2', message_body: 'hello world' }
          ]
        }
      end
      let(:expected_params) do
        {
          queue_url: queue_url,
          entries: [
            { id: 'msg1', message_body: 'test', message_attributes: message_attributes },
            { id: 'msg2', message_body: 'hello world', message_attributes: message_attributes }
          ]
        }
      end
    end
  end
end
