require "spec_helper"
require "zipkin-tracer/zipkin_sqs_sender"

describe Trace::ZipkinSqsSender do
  let(:span_id) { ZipkinTracer::TraceGenerator.new.generate_id }
  let(:trace_id) { Trace::TraceId.new(span_id, nil, span_id, true, Trace::Flags::EMPTY) }
  let(:queue_name) { "zipkin-sqs" }
  let(:region) { nil }
  let(:logger) { Logger.new(nil) }
  let(:tracer) { described_class.new(logger: logger, queue_name: queue_name, region: region) }

  describe "#initialize" do
    it 'sets the SuckerPunch logger' do
      expect(SuckerPunch).to receive(:logger=).with(logger)
      tracer
    end

    context "without region" do
      it "does not set region in sqs_options" do
        expect(tracer.instance_variable_get(:@sqs_options)).to eq({})
      end
    end

    context "with region" do
      let(:region) { "us-west-2"}

      it "sets region in sqs_options" do
        expect(tracer.instance_variable_get(:@sqs_options)).to eq(region: "us-west-2")
      end
    end
  end

  describe ":async option" do
    context "default value" do
      it "runs asynchronously" do
        expect(Trace::SqsClient).to receive(:perform_async)
        tracer.flush!
      end
    end

    context ":async is anything but a boolean with a value of 'false'" do
      it "runs asynchronously" do
        [nil, 0, "", " ", [], {}].each do |value|
          tracer = described_class.new(logger: logger, queue_name: queue_name, region: region, async: value)
          expect(Trace::SqsClient).to receive(:perform_async)
          tracer.flush!
        end
      end
    end

    context ":async is a boolean with a value of 'false'" do
      it "runs synchronously" do
        tracer = described_class.new(logger: logger, queue_name: queue_name, region: region, async: false)
        expect(Trace::SqsClient).to receive_message_chain(:new, :perform)
        tracer.flush!
      end
    end
  end

  describe "#flush!" do
    before do
      Aws.config[:sqs] = {
        stub_responses: {
          get_queue_url: {
            queue_url: "http://#{queue_name}.com"
          }
        }
      }
      Timecop.freeze
    end

    let(:name) { "test" }
    let(:span) { tracer.start_span(trace_id, name) }

    it "flushes the list of spans to SQS" do
      spans = ::ZipkinTracer::HostnameResolver.new.spans_with_ips([span], described_class::IP_FORMAT).map(&:to_h)
      expect_any_instance_of(Aws::SQS::Client)
        .to receive(:send_message).with(queue_url: "http://#{queue_name}.com", message_body: spans.to_json)
      tracer.end_span(span)
    end
  end
end
