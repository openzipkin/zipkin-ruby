# frozen_string_literal: true

module ZipkinTracer
  module B3HeaderHelper
    private

    B3_SINGLE_HEADER = 'b3'

    def set_b3_header(headers, trace_id)
      if Trace.write_b3_single_format
        headers[B3_SINGLE_HEADER] = B3SingleHeaderFormat.create_header(trace_id)
      else
        b3_headers.each do |method, header|
          header_value = trace_id.send(method).to_s
          headers[header] = header_value unless header_value.empty?
        end
      end
    end

    def b3_headers
      {
        trace_id: 'X-B3-TraceId',
        parent_id: 'X-B3-ParentSpanId',
        span_id: 'X-B3-SpanId',
        sampled: 'X-B3-Sampled',
        flags: 'X-B3-Flags'
      }
    end
  end
end
