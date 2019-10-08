# frozen_string_literal: true

module ZipkinTracer
  # This format corresponds to the propagation key "b3" (or "B3").
  # b3: {x-b3-traceid}-{x-b3-spanid}-{if x-b3-flags 'd' else x-b3-sampled}-{x-b3-parentspanid}
  # For details, see: https://github.com/openzipkin/b3-propagation
  class B3SingleHeaderFormat
    attr_reader :trace_id, :span_id, :parent_span_id, :sampled, :flags

    def initialize(trace_id: nil, span_id: nil, parent_span_id: nil, sampled: nil, flags: Trace::Flags::EMPTY)
      @trace_id = trace_id
      @span_id = span_id
      @parent_span_id = parent_span_id
      @sampled = sampled
      @flags = flags
    end

    def to_a
      [trace_id, span_id, parent_span_id, sampled, flags]
    end

    def self.parse_from_header(b3_single_header)
      return new(parse_sampled_flags(b3_single_header)) if b3_single_header.size == 1

      trace_id, span_id, flag, parent_span_id = b3_single_header.split('-')
      new(trace_id: trace_id, span_id: span_id, parent_span_id: parent_span_id, **parse_sampled_flags(flag))
    end

    def self.parse_sampled_flags(flag)
      case flag
      when '1', '0'
        { sampled: flag }
      when 'd'
        { flags: Trace::Flags::DEBUG }
      else
        {}
      end
    end
  end
end
