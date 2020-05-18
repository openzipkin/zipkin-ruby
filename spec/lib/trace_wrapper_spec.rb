require "spec_helper"
require "rspec/json_expectations"

describe ZipkinTracer::TraceWrapper do
  describe ".wrap_in_custom_span" do
    let(:service_url) { "http://service.example.com" }
    let(:zipkin_url) { "http://zipkin.example.com/api/v2/spans" }
    let(:config) do
      {
        async: false,
        service_name: "some_service",
        sample_rate: 1,
        json_api_host: zipkin_url
      }
    end

    before do
      stub_request(:get, service_url)
      stub_request(:post, zipkin_url)
      Trace.tracer = nil
    end

    it "raises if no block is given" do
      expect { described_class.wrap_in_custom_span(config, "custom span") }.to raise_error(ArgumentError)
    end

    it "passes back a NullSpan if the trace is not sampled" do
      config[:sample_rate] = 0
      described_class.wrap_in_custom_span(config, "custom span") do |span|
        expect(span).to be_instance_of(ZipkinTracer::NullSpan)
      end
    end

    it "passes back the custom span if the trace is sampled" do
      described_class.wrap_in_custom_span(config, "custom span") do |span|
        expect(span).to be_instance_of(Trace::Span)
        expect(span.name).to eq("custom span")
        expect(span.kind).to eq("SERVER")
      end
    end

    it "wraps the given block in a custom span" do
      trace_id = nil
      described_class.wrap_in_custom_span(config, "custom span") do
        conn = Faraday.new(url: service_url) do |builder|
          builder.use ZipkinTracer::FaradayHandler, config[:service_name]
          builder.adapter Faraday.default_adapter
        end
        conn.get("/")
        trace_id = ZipkinTracer::TraceContainer.current.trace_id.to_s
      end

      expect(WebMock).to have_requested(:get, service_url)
        .with(
          headers: {
            "X-B3-Traceid" => trace_id,
            "X-B3-Parentspanid" => trace_id,
            "X-B3-Spanid" => /.+/
          }
        )

      expect(WebMock).to have_requested(:post, zipkin_url)
        .with(
          body: include_json(
            [
              {
                name: "custom span",
                kind: "SERVER",
                traceId: trace_id
              },
              {
                name: "get",
                kind: "CLIENT",
                traceId: trace_id
              }
            ]
          )
        )
    end

    it "generates a new sender" do
      expect(ZipkinTracer::TracerFactory).to receive(:new).and_call_original
      described_class.wrap_in_custom_span(config, "custom span") {}
    end

    context "reuse sender if already exists" do
      before do
        Trace.tracer = Trace::NullSender.new
      end

      it "does not generate a new sender" do
        expect(ZipkinTracer::TracerFactory).not_to receive(:new)
        described_class.wrap_in_custom_span(config, "custom span") {}
      end
    end

    context "trace_context option" do
      let(:trace_context) { { trace_id: '234555b04cf7e099', span_id: '234555b04cf7e099', sampled: 'true', flags: '0' } }

      it "generates next trace_id from given trace_context hash" do
        expect(Trace::TraceId).to receive(:new).with('234555b04cf7e099', nil, '234555b04cf7e099', 'true', 0)
          .and_return(double(next_id: double(sampled?: false)))
        described_class.wrap_in_custom_span(config, "custom span", trace_context: trace_context) {}
      end

      it "generates next trace_id from ZipkinTracer::TraceGenerator when trace_context is not given" do
        expect(ZipkinTracer::TraceGenerator).to receive(:new).and_call_original
        described_class.wrap_in_custom_span(config, "custom span") {}
      end
    end
  end
end
