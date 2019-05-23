require "aws-sdk-sqs"
require "json"
require 'sucker_punch'
require "zipkin-tracer/zipkin_sender_base"
require "zipkin-tracer/hostname_resolver"

module Trace
  class SqsClient
    include SuckerPunch::Job

    def perform(sqs_options, queue_name, spans)
      spans_with_ips =
        ::ZipkinTracer::HostnameResolver.new.spans_with_ips(spans, ZipkinSqsSender::IP_FORMAT).map(&:to_h)
      sqs = Aws::SQS::Client.new(**sqs_options)
      queue_url = sqs.get_queue_url(queue_name: queue_name).queue_url
      body = JSON.generate(spans_with_ips)
      sqs.send_message(queue_url: queue_url, message_body: body)
    rescue Aws::SQS::Errors::NonExistentQueue
      error_message = "The queue '#{queue_name}' does not exist."
      SuckerPunch.logger.error(error_message)
    rescue => e
      SuckerPunch.logger.error(e)
    end
  end

  class ZipkinSqsSender < ZipkinSenderBase
    IP_FORMAT = :string

    def initialize(options)
      @sqs_options = options[:region] ? { region: options[:region] } : {}
      @queue_name = options[:queue_name]
      @async = options[:async] != false
      SuckerPunch.logger = options[:logger]
      super(options)
    end

    def flush!
      if @async
        SqsClient.perform_async(@sqs_options, @queue_name, spans.dup)
      else
        SqsClient.new.perform(@sqs_options, @queue_name, spans.dup)
      end
    end
  end
end
