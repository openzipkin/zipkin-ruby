# ZipkinTracer: Zipkin client for Ruby

[![Gitter chat](http://img.shields.io/badge/gitter-join%20chat%20%E2%86%92-brightgreen.svg)](https://gitter.im/openzipkin/zipkin)
[![Build Status](https://github.com/openzipkin/zipkin-ruby/workflows/test/badge.svg)](https://github.com/openzipkin/zipkin-ruby/actions?query=workflow%3Atest)
[![Gem Version](https://badge.fury.io/rb/zipkin-tracer.svg)](https://badge.fury.io/rb/zipkin-tracer)

Rack and Faraday integration middlewares for Zipkin tracing.

## Usage

### Sending traces on incoming requests

Options can be provided as a hash via `Rails.config.zipkin_tracer` for Rails apps or directly to the Rack middleware:

```ruby
require 'zipkin-tracer'
use ZipkinTracer::RackHandler, config
```

### Configuration options

#### Common
* `:service_name` **REQUIRED** - the name of the service being traced. There are two ways to configure this value. Either write the service name in the config file or set the "DOMAIN" environment variable (e.g. 'test-service.example.com' or 'test-service'). The environment variable takes precedence over the config file value.
* `:sample_rate` (default: 0.1) - the ratio of requests to sample, from 0 to 1
* `:sampled_as_boolean` - When set to true (default but deprecrated), it uses true/false for the `X-B3-Sampled` header. When set to false uses 1/0 which is preferred.
* `:check_routes` - When set to `true`, only routable requests are sampled. Defaults to `false`.
* `:trace_id_128bit` - When set to true, high 8-bytes will be prepended to trace_id. The upper 4-bytes are epoch seconds and the lower 4-bytes are random. This makes it convertible to Amazon X-Ray trace ID format v1. (See http://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-request-tracing.html)
* `:async` - By default senders will flush traces asynchronously. Set to `false` to make that process synchronous. Only supported by the HTTP, RabbitMQ, and SQS senders.
* `:logger` - The default logger for Rails apps is `Rails.logger`, else it is `STDOUT`. Use this option to pass a custom logger.
* `:write_b3_single_format` - When set to true, only writes a single b3 header for outbound propagation.
* `:supports_join` - When set to false, it will force client and server spans to have different spanId's. This may be needed because zipkin traces may be reported to non-zipkin backends that might not support the concept of joining spans.

#### Sender specific
* `:json_api_host` - Hostname with protocol of a zipkin api instance (e.g. `https://zipkin.example.com`) to use the HTTP sender
* `:zookeeper` - The address of the zookeeper server to use by the Kafka sender
* `:sqs_queue_name` - The name of the Amazon SQS queue to use the SQS sender
* `:sqs_region` - The AWS region for the Amazon SQS queue (optional)
* `:rabbit_mq_connection` - The bunny connection to be used by the RabbitMQ sender
* `:rabbit_mq_exchange` - The name of the exchange to be used by the RabbitMQ sender (optional)
* `:rabbit_mq_routing_key` - The name of the routing key to be used by the RabbitMQ sender (optional)
* `:log_tracing` - Set to true to log all traces. Only used if traces are not sent to the API or Kafka.

#### Plugins
* `:annotate_plugin` - Receives the Rack env, the response status, headers, and body to record annotations
* `:filter_plugin` - Receives the Rack env and will skip tracing if it returns false
* `:whitelist_plugin` - Receives the Rack env and will force sampling if it returns true

### Sending traces on outgoing requests with Faraday

For the Faraday middleware to have the correct trace ID, the rack middleware should be used in your application as explained above.

Then include `ZipkinTracer::FaradayHandler` as a Faraday middleware:

```ruby
require 'faraday'
require 'zipkin-tracer'

conn = Faraday.new(url: 'http://localhost:9292/') do |faraday|
  faraday.use ZipkinTracer::FaradayHandler, 'service_name' # 'service_name' is optional (but recommended)
  faraday.adapter Faraday.default_adapter
end
```

Note that supplying the service name for the destination service is optional;
the tracing will default to a service name derived from the first section of the destination URL (e.g. 'service.example.com' => 'service').

### Tracing Sidekiq workers

Sidekiq tracing can be turned on by adding ZipkinTracer::Sidekiq::Middleware to your sidekiq middleware chain:

```ruby
zipkin_tracer_config = {
  service_name: 'service',
  json_api_host: 'http://zipkin.io',
  traceable_workers: [:MyWorker, :MyWorker2],
  sample_rate: 0.5
}

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add ZipkinTracer::Sidekiq::Middleware, zipkin_tracer_config
  end
end
```

By default workers aren't traced. You can specify the workers that you want to trace with traceable_workers config option. If you want all your workers to be traced pass [:all] to traceable_workers option (traceable_workers: [:all]).

### Tracing Amazon SQS messages

Amazon SQS tracing can be turned on by requiring [zipkin-tracer/sqs/adapter](lib/zipkin-tracer/sqs/adapter.rb):
```ruby
require 'zipkin-tracer/sqs/adapter'
```

This SQS adapter overrides the `send_message` and `send_message_batch` methods to add trace data as message attributes and to generate a producer span when the methods are called. Since all SQS messages are affected, it is not recommended to use this feature with the [SQS sender](lib/zipkin-tracer/zipkin_sqs_sender.rb).

When receiving messages, you need to pass the `message_attribute_names: ['All']` option to retrive message attributes:
```ruby
resp = sqs.receive_message(
  queue_url: queue_url,
  message_attribute_names: ['All']
)
```

Then you can utilize the [TraceWrapper](#tracewrapper) class to generate a consumer span:
```ruby
msg = resp.messages.first
trace_context = msg.message_attributes.each_with_object({}) { |(key, value), hsh| hsh[key.to_sym] = value.string_value }

TraceWrapper.wrap_in_custom_span(config, 'receive_message',
  span_kind: Trace::Span::Kind::CONSUMER,
  trace_context: trace_context
) do |span|
  span.remote_endpoint = Trace::Endpoint.remote_endpoint(nil, 'amazon-sqs')
  span.record_tag('queue.url', queue_url)
  :
end
```

### Local tracing

`ZipkinTracer::TraceClient` provides an API to record local traces in your application.
It can be used to measure the performance of process, record value of variables, and so on.

When `local_component_span` method is called, it creates a new span and a local component, and provides the following methods to create annotations.
* record(key) - annotation
* record_tag(key, value) - tag

Example:
```ruby
ZipkinTracer::TraceClient.local_component_span('DB process') do |ztc|
  ztc.record 'Create users'
  ztc.record_tag 'number', '1000'

  # create 1000 users
end
```


## Senders

Only one of the following senders can be used at a given time.

### HTTP

Sends traces as JSON over HTTP. This is the preferred sender to use as the openzipkin project moves away from Thrift.

You need to specify the `:json_api_host` parameter to wherever your zipkin collector is running. It will POST traces to the `/api/v2/spans` path.

### Kafka

Uses Kafka as the transport.

If in the config `:zookeeper` is set, then the gem will use Kafka via
[Hermann](https://github.com/reiseburo/hermann); you will need the `hermann`
gem  (~> 0.27.0) installed, as it is not part of zipkin-tracer's gemspec.

Alternatively, you may provide a :producer option in the config; this producer
should accept #push() with a message and optional :topic.  If the value returned
responds to #value!, it will be called (to block until completed).

Caveat: Hermann is only usable from within Jruby, due to its implementation of zookeeper based broker discovery being JVM based.

The Kafka transport send data using Thrift. Since version 0.31.0, Thrift is not a dependency, thus the gem 'finagle-thrift' needs to be added to the Gemfile also.

### Amazon SQS

Uses Amazon SQS as the transport.

If `:sqs_queue_name` is set in the config, then the gem will use Amazon SQS; you will need the `aws-sdk-sqs` gem installed, as it is not part of zipkin-tracer's gemspec.

The following [Amazon SQS permissions](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-api-permissions-reference.html) are required:
- `sqs:SendMessage`
- `sqs:GetQueueUrl`

Optionally, you can set `:sqs_region` to specify the AWS region to connect to.

### RabbitMQ
Uses RabbitMQ as the transport

If `:rabbit_mq_connection` is set in the config, then the gem will use RabbitMQ. You will need to pass a [Bunny](https://github.com/ruby-amqp/bunny) connection.
You can optionally set the exchange name and routing key using `:rabbit_mq_exchange` and `:rabbit_mq_routing_key`

### Logger

The simplest sender that does something. It will log all your spans.
This sender can be used for debugging purpose (to see what is going to be sent) or to deliver zipkin information into the logs for later retrieval and analysis.

You need to set `:log_tracing` to true in the configuration.

### Null

If the configuration does not provide either an API host, Zookeeper server or Amazon SQS queue then the middlewares will not attempt to send traces although they will still generate proper IDs and pass them to other services.

Thus, if you only want to generate IDs for instance for logging and do not intent to integrate with Zipkin you can still use this gem. Just do not specify any server :)


## Plugins

### annotate_plugin
The annotate plugin expects a function of the form:

```ruby
lambda { |span, env, status, response_headers, response_body| ... }
```

The annotate plugin is expected to perform annotation based on content of the Rack environment and the response components.

**Warning:** Access to the response body may cause problems if the response is being streamed, in general this should be avoided.
See the Rack specification for more detail and instructions for properly hijacking responses.

The return value is ignored.

For example:

```ruby
lambda do |span, env, status, response_headers, response_body|
  ep = ::Trace.default_endpoint
  # string annotation
  span.record_tag('http.referrer', env['HTTP_REFERRER'])
  # integer annotation
  span.record_tag('http.content_size', env['CONTENT_SIZE'].to_s)
  span.record_tag('http.status_code', status)
end
```

### filter_plugin
The filter plugin expects a function of the form:

```ruby
lambda { |env| ... }
```

The filter plugin allows skipping tracing if the return value is false.

For example:

```ruby
# don't trace /static/ URIs
lambda { |env| env['PATH_INFO'] !~ /^\/static\// }
```

### whitelist_plugin
The whitelist plugin expects a function of the form:

```ruby
lambda { |env| ... }
```

The whitelist plugin allows forcing sampling if the return value is true.

For example:

```ruby
# sample if request header specifies known device identifier
lambda { |env| KNOWN_DEVICES.include?(env['HTTP_X_DEVICE_ID']) }
```

## Utility classes

### TraceWrapper

This class provides a `.wrap_in_custom_span` method which expects a configuration hash, a span name and a block.
You may also pass a span kind and an Application object using respectively `span_kind:` and `app:` keyword arguments.

The block you pass will be executed in the context of a custom span.
This is useful when your application doesn't use the rack handler but still needs to generate complete traces, for instance background jobs or lambdas calling remote services.

The following code will create a trace starting with a span of the (default) `SERVER` kind named "custom span" and then a span of the `CLIENT` kind will be added by the Faraday middleware. Afterwards the configured sender will call `flush!`.

```ruby
TraceWrapper.wrap_in_custom_span(config, "custom span") do |span|
  conn = Faraday.new(url: remote_service_url) do |builder|
    builder.use ZipkinTracer::FaradayHandler, config[:service_name]
    builder.adapter Faraday.default_adapter
  end
  conn.get("/")
end
```

The `trace_context:` keyword argument can be used to retrieve trace data:
```ruby
trace_context = {
  trace_id: '234555b04cf7e099',
  span_id: '234555b04cf7e099',
  sampled: 'true'
}

TraceWrapper.wrap_in_custom_span(config, "custom span", trace_context: trace_context) do |span|
  :
end
```

## Development

This project uses Rspec. Make sure your PRs contain proper tests.
We have two rake tasks to help finding performance issues:
```
rake benchmark
```
Will run a benchmark testing all the different tracers and giving you
their relative speed.

```
rake run_once
```
Will run the rack middleware, optionally the faraday middleware. Please
modify the code to run the middleware you want to test.
The best way to use this rake test is together with rbtrace.
First run the task in background:
```
rake run_once &
```
Take note of the PID that displays in your terminal and run:
```
rbtrace -p PID -f
```
It will print out the methods used and the time each took.
