require 'zipkin-tracer/sqs/adapter'

describe 'SQS Adapter' do
  let(:span_id) { ZipkinTracer::TraceGenerator.new.generate_id }
  let(:trace_id) { Trace::TraceId.new(span_id, nil, span_id, 'true', Trace::Flags::EMPTY) }
  let(:queue_url) { 'http://sqs.com' }

  before do
    allow(Trace).to receive(:tracer).and_return(nil)
    allow_any_instance_of(ZipkinTracer::TraceGenerator).to receive(:next_trace_id).and_return(trace_id)
    Aws.config[:sqs] = {
      stub_responses: {
        get_queue_url: {
          queue_url: queue_url
        }
      }
    }
  end

  shared_examples_for 'method is overridden' do |method_name|
    it 'generates a new trace_id' do
      expect_any_instance_of(ZipkinTracer::TraceGenerator).to receive(:next_trace_id)
      Aws::SQS::Client.new.send(method_name, params)
    end
  end

  describe '#send_message' do
    include_examples 'method is overridden', :send_message do
      let(:params) { { queue_url: queue_url, message_body: 'test' } }
    end
  end

  describe '#send_message_batch' do
    include_examples 'method is overridden', :send_message_batch do
      let(:params) do
        {
          queue_url: queue_url,
          entries: [
            { id: 'msg1', message_body: 'test' },
            { id: 'msg2', message_body: 'hello world' }
          ]
        }
      end
    end
  end
end
