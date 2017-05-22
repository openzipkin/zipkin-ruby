require 'rack/mock'
require 'spec_helper'

describe ZipkinTracer::RackHandler do
  def middleware(app, config={})
    configuration = { sample_rate: 1 }.merge(config)
    described_class.new(app, configuration)
  end

  def mock_env(path = '/', params = {})
    Rack::MockRequest.env_for(path, params)
  end

  def expect_host(host)
    expect(host).to be_a_kind_of(Trace::Endpoint)
    expect(host.ipv4).to eq(host_ip)
  end

  let(:app_status) { 200 }
  let(:app_headers) { { 'Content-Type' => 'text/plain' } }
  let(:app_body) { path }
  let(:path) { '/'}
  let(:tracer) { Trace.tracer }

  let(:app) {
    lambda { |env|
      [app_status, app_headers, [env['PATH_INFO']]]
    }
  }

  # stub ip address lookup
  let(:host_ip) { 0x11223344 }
  before do
    allow(::Trace::Endpoint).to receive(:host_to_i32).and_return(host_ip)
    allow(ZipkinTracer::Application).to receive(:logger).and_return(Logger.new(nil))
  end

  let(:tracer) {subject.instance_variable_get(:@tracer)}

  shared_examples_for 'traces the request' do
    it 'traces the request' do
      expect(ZipkinTracer::TraceContainer).to receive(:with_trace_id).and_call_original
      expect(tracer).to receive(:with_new_span).ordered.with(anything, 'get').and_call_original
      expect_any_instance_of(Trace::Span).to receive(:record_tag).with('http.path', '/')
      expect_any_instance_of(Trace::Span).to receive(:record).with(Trace::Annotation::SERVER_RECV)
      expect_any_instance_of(Trace::Span).to receive(:record).with(Trace::Annotation::SERVER_SEND)

      status, headers, body = subject.call(mock_env)
      expect(status).to eq(app_status)
      expect(headers).to eq(app_headers)
      expect { |b| body.each &b }.to yield_with_args(app_body)
    end
  end

  context 'Zipkin headers are passed to the middleware' do
    subject { middleware(app) }
    let(:env) { mock_env(',', ZipkinTracer::ZipkinEnv::B3_REQUIRED_HEADERS.map {|a| Hash[a, 1] }.inject(:merge)) }

    it 'does not set the RPC method' do
      expect(::Trace).not_to receive(:set_rpc_name)
      subject.call(env)
    end

    it 'does not set the path info' do
      expect_any_instance_of(Trace::Span).not_to receive(:record_tag)
      subject.call(env)
    end

    it 'force-sets the path info, excluding unknown keys' do
      expect_any_instance_of(Trace::Span).to receive(:record_tag).with('http.path', '/,')
      middleware(app, record_on_server_receive: 'whatever, http.path , unknown,keys ').call(env)
    end
  end

  context 'Using Rails' do
    subject { middleware(app) }

    context 'accessing a valid URL of our service' do
      before do
        allow(middleware(app)).to receive(:routable_request?).and_return(true)
      end

      it_should_behave_like 'traces the request'
    end

    context 'accessing an invalid URL our our service' do
      before do
        allow(middleware(app)).to receive(:routable_request?).and_return(false)
      end

      it 'calls the app' do
        status, _, body = subject.call(mock_env)
        # return expected status
        expect(status).to eq(200)
        expect { |b| body.each &b }.to yield_with_args(app_body)
      end

      it 'does not trace the request' do
        expect(::Trace).not_to receive(:push)
        expect(::Trace).not_to receive(:record)
      end
    end
  end

  context 'configured without plugins' do
    subject { middleware(app) }

    it_should_behave_like 'traces the request'

    context 'record raises socket related errors' do
      it 'calls the app normally' do
        allow(::Trace).to receive(:record).and_raise(Errno::EBADF)
        status, _, body = subject.call(mock_env)
        # return expected status
        expect(status).to eq(200)
        expect { |b| body.each &b }.to yield_with_args(app_body)
      end
    end

    context 'Zipkin methods raise exceptions' do
      it 'calls the app normally' do
        allow(::Trace).to receive(:set_rpc_name).and_raise(StandardError)
        status, _, body = subject.call(mock_env)
        # return expected status
        expect(status).to eq(200)
        expect { |b| body.each &b }.to yield_with_args(app_body)
      end
    end


    context 'with sample rate set to 0' do
      subject { middleware(app, { sample_rate: 0 }) }

      it 'Trace is created but it is not sent to zipkin' do
        expect(ZipkinTracer::TraceContainer).to receive(:with_trace_id).and_call_original
        expect(::Trace).not_to receive(:record)
        status, _, _ = subject.call(mock_env)
        expect(status).to eq(200)
      end

      it 'always samples if debug flag is passed in header' do
        expect(ZipkinTracer::TraceContainer).to receive(:with_trace_id).and_call_original
        status, _, _ = subject.call(
          mock_env('/', 'HTTP_X_B3_FLAGS' => ::Trace::Flags::DEBUG.to_s))

        # return expected status
        expect(status).to eq(200)
      end
    end
  end

  context 'configured with annotation plugin' do
    let(:annotate) do
      lambda do |span, env, status, response_headers, response_body|
        # string annotation
        span.record_tag('foo', env['foo'] || 'FOO')
        # integer annotation
        span.record_tag('http.status', [status.to_i].pack('n'), Trace::BinaryAnnotation::Type::I16, ::Trace.default_endpoint)
      end
    end
    subject { middleware(app, annotate_plugin: annotate) }

    it 'traces a request with additional annotations' do
      expect(ZipkinTracer::TraceContainer).to receive(:with_trace_id).and_call_original
      expect(tracer).to receive(:with_new_span).and_call_original.ordered

      expect_any_instance_of(Trace::Span).to receive(:record_tag).exactly(3).times
      expect_any_instance_of(Trace::Span).to receive(:record).exactly(2).times
      status, _, _ = subject.call(mock_env)

      # return expected status
      expect(status).to eq(200)
    end
  end

  context 'configured with filter plugin that allows all' do
    subject { middleware(app, filter_plugin: lambda { |env| true }) }

    it_should_behave_like 'traces the request'
  end

  context 'configured with filter plugin that allows none' do
    subject { middleware(app, filter_plugin: lambda { |env| false }) }

    it 'does not send the trace to zipkin' do
      expect(ZipkinTracer::TraceContainer).to receive(:with_trace_id).and_call_original
      expect(::Trace).not_to receive(:record)
      status, _, _ = subject.call(mock_env)
      expect(status).to eq(200)
    end
  end

  context 'with sample rate set to 0' do

    context 'configured with whitelist plugin that forces sampling' do
      subject { middleware(app, whitelist_plugin: lambda { |env| true }, sample_rate: 0) }

      it 'samples the request' do
        expect_any_instance_of(Trace::Span).to receive(:record_tag).with('http.path', '/')
        expect_any_instance_of(Trace::Span).to receive(:record).with(Trace::Annotation::SERVER_RECV)
        expect_any_instance_of(Trace::Span).to receive(:record).with('whitelisted')
        expect_any_instance_of(Trace::Span).to receive(:record).with(Trace::Annotation::SERVER_SEND)
        status, _, _ = subject.call(mock_env)
        expect(status).to eq(200)
      end
    end

    context 'configured with filter plugin that allows none' do
      subject { middleware(app, whitelist_plugin: lambda { |env| false }) }

      it_should_behave_like 'traces the request'

    end
  end
end
