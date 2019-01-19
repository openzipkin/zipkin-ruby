require 'spec_helper'

describe ZipkinTracer::TraceGenerator do
  let(:subject) { described_class.new }
  let(:trace_id_128bit) { false }

  before do
    allow(Trace).to receive(:trace_id_128bit).and_return(trace_id_128bit)
  end

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

    context 'trace_id_128bit is true' do
      let(:trace_id_128bit) { true }

      it 'returns a 128-bit traceID' do
        expect(subject.generate_trace_id.trace_id.to_s).to match(/^[a-f0-9]{32}$/i)
      end
    end
  end

  describe '#next_trace_id' do
    context 'trace container has traces' do
      let(:trace_id) { rand(1000) }
      let(:span_id) { rand(1011) }

      it 'returns the trace in the container with next span' do
        ZipkinTracer::TraceContainer.with_trace_id(Trace::TraceId.new(trace_id, nil, span_id, true.to_s, Trace::Flags::EMPTY)) do
          new_trace_id = subject.next_trace_id
          expect(new_trace_id.trace_id.to_i).to eq(trace_id)
          expect(new_trace_id.parent_id.to_i).to eq(span_id.to_i)
          expect(new_trace_id.sampled).to eq("true")
          expect(new_trace_id.flags).to eq(Trace::Flags::EMPTY)
        end
      end
    end
    context 'trace container has no traces' do
      it 'returns a traceID' do
        expect(subject.next_trace_id.class).to eq(Trace::TraceId)
      end
    end
  end

  describe '#current' do
    context 'trace container has traces' do
      let(:trace_id) { rand(1000) }
      let(:span_id) { rand(1011) }

      it 'returns the trace in the container' do
        ZipkinTracer::TraceContainer.with_trace_id(Trace::TraceId.new(trace_id, nil, span_id, true.to_s, Trace::Flags::EMPTY)) do
          new_trace_id = subject.current
          expect(new_trace_id.trace_id.to_i).to eq(trace_id)
          expect(new_trace_id.span_id.to_i).to eq(span_id.to_i)
          expect(new_trace_id.sampled).to eq("true")
          expect(new_trace_id.flags).to eq(Trace::Flags::EMPTY)
        end
      end
    end
    context 'trace container has no traces' do
      it 'returns a traceID' do
        expect(subject.current.class).to eq(Trace::TraceId)
      end
    end
  end

  describe '#generate_id_from_span_id' do
    let(:span_id) { rand(2**64) }

    context 'trace_id_128bit is false' do
      it 'returns the span_id' do
        expect(subject.generate_id_from_span_id(span_id)).to eq(span_id)
      end
    end

    context 'trace_id_128bit is true' do
      let(:trace_id_128bit) { true }
      let(:generated_id) { subject.generate_id_from_span_id(span_id) }
      let(:trace_id_low_64bit) { '%016x' % span_id }

      before do
        Timecop.freeze(Time.utc(2018, 5, 9, 14, 32))
      end

      it 'prepends high 8-bytes(4-bytes epoch seconds and 4-bytes random) to the span_id' do
        expect(generated_id.to_s(16)).to match(/^5af30660[a-f0-9]{8}#{trace_id_low_64bit}$/)
      end
    end
  end
end
