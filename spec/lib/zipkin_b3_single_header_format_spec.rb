require 'spec_helper'

describe ZipkinTracer::B3SingleHeaderFormat do
  let(:b3_single_header_format) { described_class.parse_from_header(b3_single_header) }

  context 'child span' do
    let(:b3_single_header) { '80f198ee56343ba864fe8b2a57d3eff7-e457b5a2e4d86bd1-1-05e3ac9a4f6e3b90' }

    it 'has all fields' do
      expect(b3_single_header_format.to_a).to eq(
          ['80f198ee56343ba864fe8b2a57d3eff7', 'e457b5a2e4d86bd1', '05e3ac9a4f6e3b90', '1', 0]
        )
    end
  end

  context 'sampled root span' do
    let(:b3_single_header) { '80f198ee56343ba864fe8b2a57d3eff7-e457b5a2e4d86bd1-1' }

    it 'does not have parent_span_id' do
      expect(b3_single_header_format.to_a).to eq(['80f198ee56343ba864fe8b2a57d3eff7', 'e457b5a2e4d86bd1', nil, '1', 0])
    end
  end

  context 'not yet sampled root span' do
    let(:b3_single_header) { '80f198ee56343ba864fe8b2a57d3eff7-e457b5a2e4d86bd1' }

    it 'does not have parent_span_id and sampled' do
      expect(b3_single_header_format.to_a).to eq(['80f198ee56343ba864fe8b2a57d3eff7', 'e457b5a2e4d86bd1', nil, nil, 0])
    end
  end

  context 'debug RPC child span' do
    let(:b3_single_header) { '80f198ee56343ba864fe8b2a57d3eff7-e457b5a2e4d86bd1-d-05e3ac9a4f6e3b90' }

    it 'has debug flag' do
      expect(b3_single_header_format.to_a).to eq(
          ['80f198ee56343ba864fe8b2a57d3eff7', 'e457b5a2e4d86bd1', '05e3ac9a4f6e3b90', nil, 1]
        )
    end
  end

  context 'do not sample flag only' do
    let(:b3_single_header) { '0' }

    it 'has do not sample flag only' do
      expect(b3_single_header_format.to_a).to eq([nil, nil, nil, '0', 0])
    end
  end

  context 'sampled flag only' do
    let(:b3_single_header) { '1' }

    it 'has sampled flag only' do
      expect(b3_single_header_format.to_a).to eq([nil, nil, nil, '1', 0])
    end
  end

  context 'debug flag only' do
    let(:b3_single_header) { 'd' }

    it 'has debug flag only' do
      expect(b3_single_header_format.to_a).to eq([nil, nil, nil, nil, 1])
    end
  end

  context 'unknown flag only' do
    let(:b3_single_header) { 'u' }

    it 'has nothing' do
      expect(b3_single_header_format.to_a).to eq([nil, nil, nil, nil, 0])
    end
  end
end
