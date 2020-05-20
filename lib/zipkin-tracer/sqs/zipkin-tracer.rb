module ZipkinTracer
  # This module is designed to prepend to the SQS client to add trace data as message attributes.
  # https://github.com/aws/aws-sdk-ruby/blob/master/gems/aws-sdk-sqs/lib/aws-sdk-sqs/client.rb
  module SqsHandler
    def send_message(params = {}, options = {})
      zipkin_sqs_trace_wrapper(params, __method__) { |params_with_trace| super(params_with_trace, options) }
    end

    def send_message_batch(params = {}, options = {})
      zipkin_sqs_trace_wrapper(params, __method__) { |params_with_trace| super(params_with_trace, options) }
    end

    private

    ZIPKIN_KEYS = %i[trace_id parent_id span_id sampled].freeze
    ZIPKIN_REMOTE_ENDPOINT_SQS = Trace::Endpoint.remote_endpoint(nil, 'amazon-sqs')

    def zipkin_sqs_trace_wrapper(params, method_name)
      trace_id = TraceGenerator.new.next_trace_id
      zipkin_set_message_attributes(params, method_name, trace_id)

      TraceContainer.with_trace_id(trace_id) do
        if Trace.tracer && trace_id.sampled?
          Trace.tracer.with_new_span(trace_id, method_name) do |span|
            span.kind = Trace::Span::Kind::PRODUCER
            span.remote_endpoint = ZIPKIN_REMOTE_ENDPOINT_SQS
            span.record_tag('queue.url', params[:queue_url])
            yield(params)
          end
        else
          yield(params)
        end
      end
    end

    def zipkin_set_message_attributes(params, method_name, trace_id)
      attributes = zipkin_message_attributes(trace_id)
      case method_name
      when :send_message
        params[:message_attributes] = attributes.merge(params[:message_attributes] || {})
      when :send_message_batch
        params[:entries].each do |entry|
          entry[:message_attributes] = attributes.merge(entry[:message_attributes] || {})
        end
      end
    end

    def zipkin_message_attributes(trace_id)
      ZIPKIN_KEYS.each_with_object({}) do |zipkin_key, message_attributes|
        zipkin_value = trace_id.send(zipkin_key)
        next unless zipkin_value

        message_attributes[zipkin_key] = { string_value: zipkin_value.to_s, data_type: 'String' }
      end
    end
  end
end
