require 'aws-sdk-sqs'
require 'zipkin-tracer/sqs/zipkin-tracer'

Aws::SQS::Client.prepend(ZipkinTracer::SqsHandler)
