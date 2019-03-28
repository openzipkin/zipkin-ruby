require 'rack/mock'
require 'spec_helper'

describe ZipkinTracer::ZipkinEnv do
  def mock_env(params = {}, path = '/')
    Rack::MockRequest.env_for(path, params)
  end

  let(:path) { '/to_the_lighthouse' }
  let(:sampled_as_boolean) { true }
  let(:config) do
    instance_double(
      ZipkinTracer::Config,
      filter_plugin: proc { false },
      whitelist_plugin: proc { true },
      sample_rate: 1,
      sampled_as_boolean: sampled_as_boolean
    )
  end
  let(:env) { mock_env }
  let(:zipkin_env) { described_class.new(env, config) }

  it 'allows access to the original environment' do
    expect(zipkin_env.env).to eq(env)
  end

  context 'whitelist_plugin returns false' do
    let(:config) do
      instance_double(
        ZipkinTracer::Config,
        filter_plugin: proc { false },
        whitelist_plugin: proc { false },
        sample_rate: 1,
        sampled_as_boolean: sampled_as_boolean
      )
    end

    it 'trace is not sampled' do
      expect(zipkin_env.trace_id.sampled?).to eq(false)
    end
  end

  context 'whitelist_plugin returns true' do
    let(:config) do
      instance_double(
        ZipkinTracer::Config,
        filter_plugin: proc { false },
        whitelist_plugin: proc { true },
        sample_rate: 1,
        sampled_as_boolean: sampled_as_boolean
      )
    end

    it 'trace is sampled' do
      expect(zipkin_env.trace_id.sampled?).to eq(true)
    end
  end

  context 'Not sampling in this node and not tracing information in the environment' do
    let(:config) do
      instance_double(
        ZipkinTracer::Config,
        filter_plugin: proc { false },
        whitelist_plugin: proc { false },
        sample_rate: 0,
        sampled_as_boolean: sampled_as_boolean
      )
    end

    it 'trace is not sampled' do
      expect(zipkin_env.trace_id.sampled?).to eq(false)
    end
  end

  context 'without zipkin headers' do
    let(:env) { mock_env }

    it '#called_with_zipkin_headers? returns false' do
      expect(zipkin_env.called_with_zipkin_headers?).to eq(false)
    end

    it 'generates a trace_id and a span_id' do
      trace_id = zipkin_env.trace_id
      expect(trace_id.trace_id).not_to eq(nil)
      expect(trace_id.span_id).not_to eq(nil)
      expect(trace_id.span_id.to_i).to eq(trace_id.trace_id.to_i)
    end

    it 'parent_id is nil' do
      expect(zipkin_env.trace_id.parent_id).to eq(nil)
    end

    it 'flags default to empty' do
      expect(zipkin_env.trace_id.flags).to eq(Trace::Flags::EMPTY)
    end

    it 'sampling information is set' do
      # Because sample rate == 1
      expect(zipkin_env.trace_id.sampled?).to eq(true)
    end

    it 'shared is false' do
      expect(zipkin_env.trace_id.shared).to eq(false)
    end

    context 'trace_id_128bit is true' do
      before do
        allow(Trace).to receive(:trace_id_128bit).and_return(true)
      end

      it 'generates a 128-bit trace_id' do
        expect(zipkin_env.trace_id.trace_id.to_s).to match(/^[a-f0-9]{32}$/i)
      end
    end
  end

  context 'with zipkin headers' do
    let(:id) { rand(1000) }
    let(:zipkin_headers) { { 'HTTP_X_B3_TRACEID' => id, 'HTTP_X_B3_SPANID' => id } }
    let(:env) { mock_env(zipkin_headers) }

    it '#called_with_zipkin_headers? returns true' do
      expect(zipkin_env.called_with_zipkin_headers?).to eq(true)
    end

    it 'shared is true' do
      expect(zipkin_env.trace_id.shared).to eq(true)
    end

    it 'sampling information is set' do
      # Because sample rate == 1
      expect(zipkin_env.trace_id.sampled?).to eq(true)
    end

    context 'parent_id is not provided' do
      it 'uses the trace_id and span_id' do
        trace_id = zipkin_env.trace_id
        expect(trace_id.trace_id.to_i).to eq(id)
        expect(trace_id.span_id.to_i).to eq(id)
      end

      it 'parent_id is empty' do
        expect(zipkin_env.trace_id.parent_id).to eq(nil)
      end
    end

    context 'parent_id is provided' do
      let(:parent_id) { rand(131) }
      let(:zipkin_headers) do
        { 'HTTP_X_B3_TRACEID' => id, 'HTTP_X_B3_SPANID' => id, 'HTTP_X_B3_PARENTSPANID' => parent_id }
      end

      it 'uses the trace_id and span_id' do
        trace_id = zipkin_env.trace_id
        expect(trace_id.trace_id.to_i).to eq(id)
        expect(trace_id.span_id.to_i).to eq(id)
      end

      it 'uses the parent_id' do
        expect(zipkin_env.trace_id.parent_id.to_i).to eq(parent_id)
      end
    end

    context 'all information is provided' do
      let(:parent_id) { rand(131) }
      let(:zipkin_headers) do
        { 'HTTP_X_B3_TRACEID' => id, 'HTTP_X_B3_SPANID' => id, 'HTTP_X_B3_PARENTSPANID' => parent_id,
          'HTTP_X_B3_SAMPLED' => 'true', 'HTTP_X_B3_FLAGS' => 0 }
      end

      it 'uses the trace_id and span_id' do
        trace_id = zipkin_env.trace_id
        expect(trace_id.trace_id.to_i).to eq(id)
        expect(trace_id.span_id.to_i).to eq(id)
      end

      it 'uses the parent_id' do
        expect(zipkin_env.trace_id.parent_id.to_i).to eq(parent_id)
      end

      it 'uses the sampling information' do
        expect(zipkin_env.trace_id.sampled?).to eq(true)
      end

      it 'uses the flags' do
        expect(zipkin_env.trace_id.flags.to_i).to eq(0)
      end
    end

    context 'Sampled admits using 1 as well as true' do
      let(:parent_id) { rand(131) }
      let(:zipkin_headers) do
        { 'HTTP_X_B3_TRACEID' => id, 'HTTP_X_B3_SPANID' => id, 'HTTP_X_B3_PARENTSPANID' => parent_id,
          'HTTP_X_B3_SAMPLED' => '1', 'HTTP_X_B3_FLAGS' => 0 }
      end

      it 'uses the trace_id and span_id' do
        trace_id = zipkin_env.trace_id
        expect(trace_id.trace_id.to_i).to eq(id)
        expect(trace_id.span_id.to_i).to eq(id)
      end

      it 'uses the parent_id' do
        expect(zipkin_env.trace_id.parent_id.to_i).to eq(parent_id)
      end

      it 'uses the sampling information' do
        expect(zipkin_env.trace_id.sampled?).to eq(true)
      end

      it 'uses the flags' do
        expect(zipkin_env.trace_id.flags.to_i).to eq(0)
      end
    end
  end
end
