require 'spec_helper'

describe ZipkinTracer::TraceGenerator do
  let(:subject) { described_class.new }

  describe '#generate_id' do
    it 'returns a traceID' do
      expect(subject.generate_trace_id.class).to eq(Trace::TraceId)
    end

    it 'is a sampled trace if sampling' do
      allow(Trace).to receive(:sample_rate).and_return(1)
      trace_id = subject.generate_trace_id
      expect(trace_id.sampled?).to eq(true)
    end

    it 'is not sampled trace if not sampling' do
      allow(Trace).to receive(:sample_rate).and_return(0)
      trace_id = subject.generate_trace_id
      expect(trace_id.sampled?).to eq(false)
    end
  end

  describe '#next_trace_id' do
    context 'trace container has traces' do
      let(:trace_id) { rand(1000) }
      let(:span_id) { rand(1011) }

      it 'returns the trace in the container' do
        ZipkinTracer::TraceContainer.with_trace_id(Trace::TraceId.new(trace_id, nil, span_id, true.to_s, Trace::Flags::EMPTY)) do
          new_trace_id = subject.next_trace_id
          expect(new_trace_id.trace_id.to_i).to eq(trace_id)
          expect(new_trace_id.parent_id.to_i).to eq(span_id.to_i)
        end
      end
    end
  end

end
