require 'spec_helper'
require 'zipkin-tracer/zipkin_json_tracer'

describe Trace::ZipkinJsonTracer do
  let(:span_id) { 'c3a555b04cf7e099' }
  let(:parent_id) { 'f0e71086411b1445' }
  let(:sampled) { true }
  let(:trace_id) { Trace::TraceId.new(span_id, nil, span_id, sampled, Trace::Flags::EMPTY) }
  let(:dummy_endpoint) { Trace::Endpoint.new('127.0.0.1', 9411, 'DummyService') }
  let(:annotation) { Trace::Annotation.new(Trace::Annotation::SERVER_RECV, dummy_endpoint) }
  let(:binary_annotation) { Trace::BinaryAnnotation.new('http.uri', '/', 'STRING', dummy_endpoint) }
  let(:name) { 'GET' }
  let(:span) { tracer.start_span(trace_id, name) }

  let(:json_api_host) { 'http://json.example.com' }
  let(:default_options) { { json_api_host: json_api_host } }
  let(:tracer) { described_class.new(default_options) }

  describe '#record' do

    context 'sampling' do
      let(:nb_traces) { 3 }
      let(:span_hash) { {
        name: name,
        traceId: span_id,
        id: span_id,
        parentId: nil,
        annotations: [],
        binaryAnnotations: [],
        timestamp: 1452987900000000,
        duration: 0,
        debug: false
      } }
      let(:dummy_binary_annotations) {
        [ { key: 'http.uri', value: '/', endpoint: dummy_endpoint.to_h } ]
      }
      let(:dummy_annotations) {
        [ { value: 'sr', timestamp: 1452987900000000, endpoint: dummy_endpoint.to_h } ]
      }
      let(:stub_post_request) do
        lambda { |body|
          stub_request(:post, json_api_host + AsyncJsonApiClient::SPANS_PATH).with(
            headers: { 'Content-Type' => 'application/json' },
            body: JSON.generate(body)
          )
        }
      end

      before { Timecop.freeze(Time.utc(2016, 1, 16, 23, 45)) }

    end
  end

  describe '#initialize' do
    let(:logger) { nil }
    it 'sets the SuckerPunch logger' do
      expect(SuckerPunch).to receive(:logger=).with(logger)
      described_class.new(default_options.merge(logger: logger))
    end
  end

end
