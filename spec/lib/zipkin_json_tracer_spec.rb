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
  let(:traces_buffer) { 1 }
  let(:default_options) { { json_api_host: json_api_host, traces_buffer: traces_buffer } }
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

      context 'traces_buffer == 1 (no buffering)' do
        before { expect(tracer).to receive(:flush!).exactly(nb_traces).times.and_call_original }

        it 'records a binary annotation' do
          stub_post_request.([span_hash.merge(binaryAnnotations: dummy_binary_annotations)])
          nb_traces.times do
            tracer.with_new_span(trace_id, name) do |span|
              span.record(binary_annotation)
            end
          end
        end

        it 'records an annotation' do
          stub_post_request.([span_hash.merge(annotations: dummy_annotations)])
          nb_traces.times do
            tracer.with_new_span(trace_id, name) do |span|
              span.record(annotation)
            end
          end
        end
      end

      context 'traces_buffer > 1' do
        let(:traces_buffer) { 3 }
        before { expect(tracer).to receive(:flush!).exactly(2).times.and_call_original }

        it 'records several binary annotations' do
          stub_post_request.([span_hash.merge(binaryAnnotations: dummy_binary_annotations * 3)])
          (nb_traces * 2).times do
            tracer.with_new_span(trace_id, name) do |span|
              span.record(binary_annotation)
            end
          end
        end

        it 'records several annotations' do
          stub_post_request.([span_hash.merge(annotations: dummy_annotations * 3)])
          (nb_traces * 2).times do
            tracer.with_new_span(trace_id, name) do |span|
              span.record(annotation)
            end
          end
        end
      end
    end
  end

  describe '#initialize' do
    let(:logger) { nil }
    it 'sets the SuckerPunch logger' do
      expect(SuckerPunch).to receive(:logger=).with(logger)
      described_class.new(default_options.merge(logger: logger))
    end
  end

  describe '#start_span' do
    let(:rpc_name) { 'this_is_an_rpc' }

    context 'sampling' do
      it 'sets the span name' do
        span = Trace::Span.new('', trace_id)
        allow(tracer).to receive(:get_span_for_id).and_return(span)
        expect(span).to receive(:name=).with(rpc_name)
        tracer.start_span(trace_id, rpc_name)
      end
    end
  end
end
