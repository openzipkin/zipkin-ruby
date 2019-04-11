require "aws-sdk-sqs"
require "json"
require "zipkin-tracer/zipkin_sender_base"
require "zipkin-tracer/hostname_resolver"

module Trace
  class ZipkinSqsSender < ZipkinSenderBase
    IP_FORMAT = :string

    def initialize(options)
      sqs_options = options[:region] ? { region: options[:region] } : {}
      @sqs = Aws::SQS::Client.new(**sqs_options)
      @queue_name = options[:queue_name]
      @logger = options[:logger]
      super(options)
    end

    def flush!
      queue_url = @sqs.get_queue_url(queue_name: @queue_name).queue_url
      resolved_spans = ::ZipkinTracer::HostnameResolver.new.spans_with_ips(spans, IP_FORMAT).map(&:to_h)
      @sqs.send_message(queue_url: queue_url, message_body: JSON.generate(resolved_spans))
    rescue Aws::SQS::Errors::NonExistentQueue
      error_message = "A queue named '#{@queue_name}' does not exist."
      @logger.error(error_message)
    rescue => e
      @logger.error(e)
    end
  end
end
