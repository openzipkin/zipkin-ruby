require 'spec_helper'
require 'zipkin-tracer/zipkin_rabbit_mq_sender'

describe Trace::ZipkinRabbitMqSender do
  let(:span_id) { ZipkinTracer::TraceGenerator.new.generate_id }
  let(:trace_id) { Trace::TraceId.new(span_id, nil, span_id, true, Trace::Flags::EMPTY) }
  let(:rabbit_mq_connection) { double('RabbitMQ connection') }
  let(:rabbit_mq_exchange) { 'zipkin.exchange' }
  let(:rabbit_mq_routing_key) { 'routing.key' }
  let(:publisher) { double('publisher') }
  let(:tracer) do
    described_class.new(
      rabbit_mq_connection: rabbit_mq_connection,
      rabbit_mq_exchange: rabbit_mq_exchange,
      rabbit_mq_routing_key: rabbit_mq_routing_key
    )
  end

  before do
    allow(publisher).to receive(:publish)
    allow(Trace::RabbitMqPublisher).to receive(:new).and_return(publisher)
  end

  describe '#flush!' do
    let(:name) { 'test' }
    let(:span) do
      tracer.start_span(trace_id, name).tap do |spn|
        spn.local_endpoint = endpoint
        spn.remote_endpoint = endpoint
      end
    end
    let(:spans) do
      ::ZipkinTracer::HostnameResolver.new
        .spans_with_ips([span], described_class::IP_FORMAT)
        .map(&:to_h)
    end
    let(:ipv4) { '10.10.10.10' }
    let(:hostname) { 'hostname' }
    let(:endpoint) { Trace::Endpoint.new(hostname, 80, name) }
    let(:expected_message) do
      [{
        name: name,
        traceId: trace_id.trace_id,
        id: trace_id.trace_id,
        localEndpoint: {
          ipv4: ipv4,
          serviceName: name,
          port: 80
        },
        timestamp: 1570702210000000,
        duration: 0,
        debug: false,
        remoteEndpoint: {
          ipv4: ipv4,
          serviceName: name,
          port: 80
        },
      }].to_json
    end

    before do
      Timecop.freeze('2019-10-10 10:10:10 +0000')
      allow(Socket).to receive(:getaddrinfo).and_return([[nil, nil, nil, ipv4]])
    end

    context 'when all parameters are configured' do
      it 'flushes the list of spans to to to publisher' do
        expect(publisher)
          .to receive(:publish)
          .with(rabbit_mq_exchange, rabbit_mq_routing_key, expected_message)

        tracer.end_span(span)
      end
    end

    context 'when exchange is not configured' do
      let(:rabbit_mq_exchange) { nil }

      it 'flushes the list of spans to to to publisher with default exchange' do
        expect(publisher)
          .to receive(:publish)
          .with('', rabbit_mq_routing_key, expected_message)

        tracer.end_span(span)
      end
    end

    context 'when routing key is not configured' do
      let(:rabbit_mq_routing_key) { nil }

      it 'flushes the list of spans to to to publisher with default routing key' do
        expect(publisher)
          .to receive(:publish)
          .with(rabbit_mq_exchange, 'zipkin', expected_message)

        tracer.end_span(span)
      end
    end
  end
end
