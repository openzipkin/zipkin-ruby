require 'rack/mock'
require 'spec_helper'

describe ZipkinTracer::RackHandler do
  def middleware(app, config={})
    ZipkinTracer::RackHandler.new(app, config)
  end

  def mock_env(path = '/', params = {})
    @request = Rack::MockRequest.env_for(path, params)
  end

  let(:app) {
    lambda { |env|
      [200, { 'Content-Type' => 'text/plain' }, ['hello']]
    }
  }

  # stub ip address lookup
  let(:host_ip) { 0x11223344 }
  before(:each) {
    allow(::Trace::Endpoint).to receive(:host_to_i32).and_return(host_ip)
  }


  shared_examples_for 'traces the request' do
    it 'traces the request' do
      expect(::Trace).to receive(:push).ordered
      expect(::Trace).to receive(:set_rpc_name).ordered.with('get')
      expect(::Trace).to receive(:pop).ordered
      expect(::Trace).to receive(:record).exactly(3).times
      status, headers, body = subject.call(mock_env)

      # return expected status
      expect(status).to eq(200)
      expect { |b| body.each &b }.to yield_with_args('hello')
    end
  end

  describe 'initializer' do
    context 'configured to use kafka', :platform => :java do
      let(:zookeeper) { 'localhost:2181' }
      let(:zipkinKafkaTracer) { double('ZipkinKafkaTracer') }

      it 'creates a zipkin kafka tracer' do
        allow(::Trace::ZipkinKafkaTracer).to receive(:new) { zipkinKafkaTracer }
        expect(::Trace).to receive(:tracer=).with(zipkinKafkaTracer)
        expect(zipkinKafkaTracer).to receive(:connect)
        middleware(app, :zookeeper => zookeeper)
      end
    end

    context 'configured to use scribe' do
      subject { middleware(app, logger: Logger.new(nil), scribe_server: 'fake_scribe_server') }
      it_should_behave_like 'traces the request'

      it 'creates a zipkin scribe tracer' do
        expect(::Trace::ZipkinTracer).to receive(:new)
        middleware(app, logger: Logger.new(nil), scribe_server: 'fake_scribe_server')
      end
    end

    context 'no transport configured' do
      subject { middleware(app, logger: Logger.new(nil)) }
      it_should_behave_like 'traces the request'

      it 'creates a null scribe tracer' do
        expect(::Trace::NullTracer).to receive(:new)
        middleware(app, logger: Logger.new(nil))
      end
    end

    describe 'sample rate initialization' do
      let(:sample_rate) { 0.42 }
      subject { middleware(app, logger: Logger.new(nil), sample_rate: sample_rate) }
      it 'sets the sample rate' do
        expect(::Trace).to receive(:sample_rate=).with(sample_rate)
        subject.call(mock_env)
      end

    end

  end

  context 'Zipkin headers are passed to the middlewawre' do
    subject { middleware(app, logger: Logger.new(nil)) }
    let(:env) {mock_env(',', ZipkinTracer::RackHandler::B3_REQUIRED_HEADERS.map {|a| Hash[a, 1] }.inject(:merge))}
    it 'does not set the RPC method' do
      expect(::Trace).not_to receive(:set_rpc_name)
      status, headers, body = subject.call(env)
    end
  end

  context 'Using Rails' do
    subject { middleware(app, logger: Logger.new(nil)) }

    context 'accessing a valid URL of our service' do
      before do
        rails = double("Rails")
        allow(rails).to receive_message_chain(:application, :routes, :recognize_path).and_return({controller: 'trusmis', action: 'new'})
        stub_const("Rails", rails)
      end
      it_should_behave_like 'traces the request'
    end

    context 'accessing an invalid URL our our service' do
      before do
        rails = double("Rails")
        stub_const('ActionController::RoutingError', StandardError)
        allow(rails).to receive_message_chain(:application, :routes, :recognize_path).and_raise(ActionController::RoutingError)
        stub_const("Rails", rails)
      end

      it 'calls the app' do
        status, headers, body = subject.call(mock_env)
        # return expected status
        expect(status).to eq(200)
        expect { |b| body.each &b }.to yield_with_args('hello')
      end

      it 'does not trace the request' do
        expect(::Trace).not_to receive(:push)
        expect(::Trace).not_to receive(:record)
      end
    end
  end

  context 'configured without plugins' do
    subject { middleware(app, logger: Logger.new(nil)) }

    it_should_behave_like 'traces the request'

    it 'calls the app even when the tracer raises while the call method is called' do
      allow(::Trace).to receive(:record).and_raise(Errno::EBADF)
      status, headers, body = subject.call(mock_env)
      # return expected status
      expect(status).to eq(200)
      expect { |b| body.each &b }.to yield_with_args('hello')
    end

    context 'with sample rate set to 0' do
      before(:each) { ::Trace.sample_rate = 0 }

      it 'does not sample a request' do
        # mock should_sample? because it has a rand and produces
        # non-deterministic results
        allow(::Trace).to receive(:should_sample?) { false }
        expect(::Trace).to receive(:push) do |trace_id|
          expect(trace_id.sampled?).to be_falsy
        end
        status, headers, body = subject.call(mock_env())
        # return expected status
        expect(status).to eq(200)
      end

      it 'always samples if debug flag is passed in header' do
        expect(::Trace).to receive(:push) do |trace_id|
          expect(trace_id.sampled?).to be_truthy
        end
        status, headers, body = subject.call(
          mock_env('/', 'HTTP_X_B3_FLAGS' => ::Trace::Flags::DEBUG.to_s))

        # return expected status
        expect(status).to eq(200)
      end
    end
  end

  context 'configured with annotation plugin' do
    let(:annotate) do
      lambda do |env, status, response_headers, response_body|
        # string annotation
        ::Trace.record(::Trace::BinaryAnnotation.new('foo', env['foo'] || 'FOO', 'STRING', ::Trace.default_endpoint))
        # integer annotation
        ::Trace.record(::Trace::BinaryAnnotation.new('http.status', [status.to_i].pack('n'), 'I16', ::Trace.default_endpoint))
      end
    end
    subject { middleware(app, :annotate_plugin => annotate) }

    it 'traces a request with additional annotations' do
      expect(::Trace).to receive(:push).ordered
      expect(::Trace).to receive(:set_rpc_name).ordered
      expect(::Trace).to receive(:pop).ordered
      expect(::Trace).to receive(:record).exactly(5).times
      status, headers, body = subject.call(mock_env)

      # return expected status
      expect(status).to eq(200)
    end
  end

  context 'configured with filter plugin that allows all' do
    subject { middleware(app, :filter_plugin => lambda {|env| true}) }

    it_should_behave_like 'traces the request'

  end

  context 'configured with filter plugin that allows none' do
    subject { middleware(app, :filter_plugin => lambda {|env| false}) }

    it 'does not trace the request' do
      expect(::Trace).not_to receive(:push)
      status, _, _ = subject.call(mock_env)
      expect(status).to eq(200)
    end
  end

  context 'with sample rate set to 0' do
    before(:each) { ::Trace.sample_rate = 0 }

    context 'configured with whitelist plugin that forces sampling' do
      subject { middleware(app, :whitelist_plugin => lambda {|env| true}) }

      it 'samples the request' do
        expect(::Trace).to receive(:push) do |trace_id|
          expect(trace_id.sampled?).to be_truthy
        end
        expect(::Trace).to receive(:record).exactly(4).times # extra whitelisted annotation
        status, _, _ = subject.call(mock_env)
        expect(status).to eq(200)
      end
    end

    context 'configured with filter plugin that allows none' do
      subject { middleware(app, :whitelist_plugin => lambda {|env| false}) }

      it 'does not sample the request' do
        allow(::Trace).to receive(:should_sample?) { false }
        expect(::Trace).to receive(:push) do |trace_id|
          expect(trace_id.sampled?).to be_falsey
        end
        expect(::Trace).to receive(:record).exactly(3).times # normal annotations
        status, _, _ = subject.call(mock_env)
        expect(status).to eq(200)
      end
    end
  end
end
