# frozen_string_literal: true

module ZipkinTracer
  # This format corresponds to the propagation key "b3" (or "B3").
  # b3: {x-b3-traceid}-{x-b3-spanid}-{if x-b3-flags 'd' else x-b3-sampled}-{x-b3-parentspanid}
  # For details, see: https://github.com/openzipkin/b3-propagation
  class B3SingleHeaderFormat
    def self.parse_from_header(b3_single_header)
      if b3_single_header.size == 1
        flag = b3_single_header
      else
        trace_id, span_id, flag, parent_span_id = b3_single_header.split('-')
      end
      [trace_id, span_id, parent_span_id, parse_sampled(flag), parse_flags(flag)]
    end

    def self.parse_sampled(flag)
      case flag
      when '1', '0'
        flag
      end
    end

    def self.parse_flags(flag)
      flag == 'd' ? Trace::Flags::DEBUG : Trace::Flags::EMPTY
    end
  end
end
