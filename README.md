# ZipkinTracer

[![Build Status](https://api.travis-ci.org/openzipkin/zipkin-tracer.svg?branch=master)](https://travis-ci.org/openzipkin/zipkin-tracer)

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
* `:service_port` **REQUIRED** - the port of the service being traced (e.g. 80 or 443)
* `:sample_rate` (default: 0.1) - the ratio of requests to sample, from 0 to 1
* `:logger` - A logger class following the standard's library Logger interface (Log4r, Rails.logger, etc).
* `:json_api_host` - hostname with protocol of a zipkin api instance (e.g. `https://zipkin.example.com`) to use the JSON tracer
* `:traces_buffer` (default: 100) - the number of annotations stored by the JSON tracer until automatic flush (note that annotations are also flushed when the request is complete)
* `:zookeeper` - the address of the zookeeper server to use by the Kafka tracer
* `:scribe_server` (default from scribe gem) - the address of the scribe server where traces are delivered
* `:scribe_max_buffer` (default: 10) - the number of annotations stored by the Scribe tracer until automatic flush (note that annotations are also flushed when the request is complete)
* `:annotate_plugin` - plugin function which receives the Rack env, the response status, headers, and body to record annotations
* `:filter_plugin` - plugin function which receives the Rack env and will skip tracing if it returns false
* `:whitelist_plugin` - plugin function which receives the Rack env and will force sampling if it returns true


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


### Local tracing

`ZipkinTracer::TraceClient` provides an API to record local traces in your application.
It can be used to measure the performance of process, record value of variables, and so on.

When `local_component_span` method is called, it creates a new span and a local component, and provides the following methods to create annotations.
* record(key) - annotation
* record_tag(key, value) - binary annotation

Example:
```ruby
ZipkinTracer::TraceClient.local_component_span('Local Trace') do |ztc|
  ztc.record 'New Annotation'
  ztc.record_tag 'key', 'sample'
  # target process
end
```


## Tracers

### JSON

Sends traces as JSON over HTTP. This is the preferred tracer to use as the openzipkin project moves away from Thrift.

You need to specify the `:json_api_host` parameter to wherever your zipkin collector is running. It will POST traces to the `/api/v1/spans` path.

By default it buffers the traces call so as not to hammer your zipkin instance. This can be configured using the `:traces_buffer` parameter.


### Kafka

Uses Kafka as the transport instead of scribe.

If in the config `:zookeeper` is set, then the gem will use Kafka.
Hermann is the kafka client library that you will need to explicitly install if you want to use this tracer.

Caveat: Hermann is only usable from within Jruby, due to its implementation of zookeeper based broker discovery being JVM based.

```ruby
# zipkin-kafka-tracer requires Hermann 0.25.0 or later
gem 'hermann', '~> 0.25'
```

### Scribe

The original tracer, it uses scribe and thrift to send traces.

You need to explicitly install the gem (`gem 'scribe', '~> 0.2.4'`) and set `:scribe_server` in the config.


### Null

If the configuration does not provide either a JSON, Zookeeper or Scribe server then the middlewares will not attempt to send traces although they will still generate proper IDs and pass them to other services.

Thus, if you only want to generate IDs for instance for logging and do not intent to integrate with Zipkin you can still use this gem. Just do not specify any server :)



## Plugins

### annotate_plugin
The annotate plugin expects a function of the form:

```ruby
lambda { |env, status, response_headers, response_body| ... }
```

The annotate plugin is expected to perform annotation based on content of the Rack environment and the response components.

**Warning:** Access to the response body may cause problems if the response is being streamed, in general this should be avoided.
See the Rack specification for more detail and instructions for properly hijacking responses.

The return value is ignored.

For example:

```ruby
lambda do |env, status, response_headers, response_body|
  ep = ::Trace.default_endpoint
  # string annotation
  ::Trace.record(::Trace::BinaryAnnotation.new('http.referrer', env['HTTP_REFERRER'], 'STRING', ep))
  # integer annotation
  ::Trace.record(::Trace::BinaryAnnotation.new('http.content_size', [env['CONTENT_SIZE']].pack('N'), 'I32', ep))
  ::Trace.record(::Trace::BinaryAnnotation.new('http.status', [status.to_i].pack('n'), 'I16', ep))
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
lambda { |env| env['PATH_INFO'] ~! /^\/static\// }
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
We have two rake task to help finding performance issues:
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
