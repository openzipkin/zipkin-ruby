require 'spec_helper'
require 'zipkin-tracer/zipkin_rabbit_mq_sender'

describe Trace::ZipkinRabbitMqSender do
  let(:span_id) { ZipkinTracer::TraceGenerator.new.generate_id }
  let(:trace_id) { Trace::TraceId.new(span_id, nil, span_id, true, Trace::Flags::EMPTY) }
  let(:rabbit_mq_connection) { double('RabbitMQ connection') }
  let(:rabbit_mq_exchange) { 'zipkin.exchange' }
  let(:rabbit_mq_routing_key) { 'routing.key' }
  let(:channel) { double('channel') }
  let(:exchange) { double('exchange') }
  let(:logger) { Logger.new(nil) }
  let(:tracer) do
    described_class.new(
      rabbit_mq_connection: rabbit_mq_connection,
      rabbit_mq_exchange: rabbit_mq_exchange,
      rabbit_mq_routing_key: rabbit_mq_routing_key,
      logger: logger
    )
  end

  before do
    allow(rabbit_mq_connection).to receive(:create_channel).and_return(channel)
    allow(channel).to receive(:exchange).and_return(exchange)
    allow(exchange).to receive(:publish)
    allow(SuckerPunch).to receive(:logger=)
  end

  describe '#initialize' do
    subject { tracer }

    it 'sets the SuckerPunch logger' do
      subject

      expect(SuckerPunch).to have_received(:logger=).with(logger)
    end

    describe ':async option' do
      include_examples 'async option passed to senders' do
        let(:sender_class) { described_class }
        let(:job_class) { Trace::RabbitMqPublisher }
        let(:options) do
          {
            rabbit_mq_connection: rabbit_mq_connection,
            rabbit_mq_exchange: rabbit_mq_exchange,
            rabbit_mq_routing_key: rabbit_mq_routing_key,
            logger: logger
          }
        end
      end
    end

    describe 'exchange' do
      context 'when rabbit_mq_exchange is configured' do
        it 'sets the exchange correctly' do
          subject

          expect(channel).to have_received(:exchange).with(rabbit_mq_exchange)
        end
      end

      context 'when rabbit_mq_exchange is not configured' do
        let(:rabbit_mq_exchange) { nil }

        it 'sets the exchange using the default exchange value' do
          subject

          expect(channel).to have_received(:exchange).with('')
        end
      end
    end
  end

  describe '#flush!' do
    let(:name) { 'test' }
    let(:span) do
      tracer.start_span(trace_id, name).tap do |spn|
        spn.local_endpoint = endpoint
        spn.remote_endpoint = endpoint
      end
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
      it 'flushes the list of spans' do
        tracer.end_span(span)

        expect(exchange)
          .to have_received(:publish)
          .with(expected_message, routing_key: rabbit_mq_routing_key)
      end
    end

    context 'when routing_key is not configured' do
      let(:rabbit_mq_routing_key) { nil }

      it 'flushes the list of spans to the default routing key' do
        tracer.end_span(span)

        expect(exchange)
          .to have_received(:publish)
          .with(expected_message, routing_key: 'zipkin')
      end
    end
  end
end
