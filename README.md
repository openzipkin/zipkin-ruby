# ZipkinTracer: Zipkin client for Ruby

[![Build Status](https://api.travis-ci.org/openzipkin/zipkin-ruby.svg?branch=master)](https://travis-ci.org/openzipkin/zipkin-ruby)

Rack and Faraday integration middlewares for Zipkin tracing.

## Usage

### Sending traces on incoming requests

Options can be provided via Rails.config for a Rails 3+ app, or can be passed as a hash argument to the Rack plugin.

```ruby
require 'zipkin-tracer'
use ZipkinTracer::RackHandler, config # config is optional
```

where `Rails.config.zipkin_tracer` or `config` is a hash that can contain the following keys:

* `:service_name` **REQUIRED** - the name of the service being traced. There are two ways to configure this value. Either write the service name in the config file or set the "DOMAIN" environment variable (e.g. 'test-service.example.com' or 'test-service'). The environment variable takes precedence over the config file value.
* `:sample_rate` (default: 0.1) - the ratio of requests to sample, from 0 to 1
* `:json_api_host` - hostname with protocol of a zipkin api instance (e.g. `https://zipkin.example.com`) to use the JSON tracer
* `:zookeeper` - the address of the zookeeper server to use by the Kafka tracer
* `:log_tracing` - Set to true to log all traces. Only used if traces are not sent to the API or Kafka.
* `:annotate_plugin` - plugin function which receives the Rack env, the response status, headers, and body to record annotations
* `:filter_plugin` - plugin function which receives the Rack env and will skip tracing if it returns false
* `:whitelist_plugin` - plugin function which receives the Rack env and will force sampling if it returns true
* `:sampled_as_boolean` - When set to true (default but deprecrated), it uses true/false for the `X-B3-Sampled` header. When set to false uses 1/0 which is preferred.
* `:trace_id_128bit` - When set to true, high 8-bytes will be prepended to trace_id. The upper 4-bytes are epoch seconds and the lower 4-bytes are random. This makes it convertible to Amazon X-Ray trace ID format v1. (See http://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-request-tracing.html)

### Sending traces on outgoing requests with Faraday

First, Faraday has to be part of your Gemfile:
```
gem 'faraday', '~> 0.8'
```

For the Faraday middleware to have the correct trace ID, the rack middleware should be used in your application as explained above.

Then include `ZipkinTracer::FaradayHandler` as a Faraday middleware:

```ruby
require 'faraday'
require 'zipkin-tracer'

conn = Faraday.new(:url => 'http://localhost:9292/') do |faraday|
  faraday.use ZipkinTracer::FaradayHandler, 'service_name' # 'service_name' is optional (but recommended)
  # default Faraday stack
  faraday.request :url_encoded
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


## Tracers

Only one of the following tracers can be used at a given time.

### JSON

Sends traces as JSON over HTTP. This is the preferred tracer to use as the openzipkin project moves away from Thrift.

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

### Logger

The simplest tracer that does something. It will log all your spans.
This tracer can be used for debugging purpose (to see what is going to be sent) or to deliver zipkin information into the logs for later retrieval and analysis.

You need to set `:log_tracing` to true in the configuration.

### Null

If the configuration does not provide either a JSON, Zookeeper or Scribe server then the middlewares will not attempt to send traces although they will still generate proper IDs and pass them to other services.

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
