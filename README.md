# ZipkinTracer

[![Build Status](https://api.travis-ci.org/openzipkin/zipkin-tracer.svg?branch=master)](https://travis-ci.org/openzipkin/zipkin-tracer)

Rack and Faraday integration middlewares for Zipkin tracing.

## Usage

### Sending traces on incoming requests

Options can be provided via Rails.config for a Rails 3+ app, or can be passed
as a hash argument to the Rack plugin.

    require 'zipkin-tracer'
    use ZipkinTracer::RackHandler, config # config is optional

where Rails.config.zipkin_tracer or config is a hash that can contain the following keys:

 * `:service_name` (REQUIRED) - the name of the service being traced. There are two ways to configure this
   value. Either write the service name in the config file or set the "DOMAIN"
   environment variable (e.g. 'test-service.example.com' or 'test-service'). The
   environment variable takes precedence over the config file value.
 * `:service_port` (REQUIRED) - the port of the service being traced (e.g. 80 or 443)
 * `:scribe_server` (default from scribe gem) - the address of the scribe server where traces are delivered
 * `:scribe_max_buffer` (default: 10) - the number of annotations stored until automatic flush
       (note that annotations are also flushed when the request is complete)
 * `:sample_rate` (default: 0.1) - the ratio of requests to sample, from 0 to 1
 * `:annotate_plugin` - plugin function which recieves Rack env, and
   response status, headers, and body; and can record annotations
 * `:filter_plugin` - plugin function which recieves Rack env and will skip tracing if it returns false
 * `:whitelist_plugin` - plugin function which recieves Rack env and will force sampling if it returns true
 * `:zookeeper` - plugin function which uses zookeeper and kafka instead of scribe as the transport
 * `:logger` - A logger class following the standard's library Logger interface (Log4r, Rails.logger, etc).
 * `:json_api_host` - hostname with protocol of a zipkin api instance (e.g. `https://zipkin.example.com`) to use JSON over HTTP instead of Scribe or Kafka
 * `:traces_buffer` (default: 100) - the number of annotations stored until automatic flush
   (note that annotations are also flushed when the request is complete)


 If the configuration does not provide either a JSON, Scribe or Zookeeper server then the middlewares will not
 attempt to send traces although they will still generate proper IDs and pass them to other services.
 Thus, if you only want to generate IDs for instance for logging and do not intent to integrate with Zipkin,
 you can still use this gem. Just do not specify any server :)


### Warning

NOTE that access to the response body (available in the annotate
plugin) may cause problems in the case that a response is being
streamed; in general, this should be avoided (see the Rack
specification for more detail and instructions for properly hijacking
responses).


### Sending traces on outgoing requests with Faraday

First, Faraday has to be part of your Gemfile:
```
gem 'faraday', '~> 0.8'
```

For the Faraday middleware to have the correct trace ID, the rack middleware should be used in your application as explained above.

Then include ZipkinTracer::FaradayHandler as a Faraday middleware:

    require 'faraday'
    require 'zipkin-tracer'

    conn = Faraday.new(:url => 'http://localhost:9292/') do |faraday|
      # 'service_name' is optional (but recommended)
      faraday.use ZipkinTracer::FaradayHandler, 'service_name'
      # default Faraday stack
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
    end

Note that supplying the service name for the destination service is
optional; the tracing will default to a service name derived from the
first section of the destination URL (e.g. 'service.example.com' =>
'service').


## Plugins

### annotate_plugin
The annotate plugin expects a function of the form:

    lambda {|env, status, response_headers, response_body| ...}

The annotate plugin is expected to perform annotation based on content
of the Rack environment and the response components. The return value
is ignored.

For example:

    lambda do |env, status, response_headers, response_body|
      # string annotation
      ::Trace.record(::Trace::BinaryAnnotation.new('http.referrer', env['HTTP_REFERRER'], 'STRING', ::Trace.default_endpoint))
      # integer annotation
      ::Trace.record(::Trace::BinaryAnnotation.new('http.content_size', [env['CONTENT_SIZE']].pack('N'), 'I32', ::Trace.default_endpoint))
      ::Trace.record(::Trace::BinaryAnnotation.new('http.status', [status.to_i].pack('n'), 'I16', ::Trace.default_endpoint))
    end

### filter_plugin
The filter plugin expects a function of the form:

    lambda {|env| ...}

The filter plugin allows skipping tracing if the return value is
false.

For example:

    # don't trace /static/ URIs
    lambda {|env| env['PATH_INFO'] ~! /^\/static\//}

### whitelist_plugin
The whitelist plugin expects a function of the form:

    lambda {|env| ...}

The whitelist plugin allows forcing sampling if the return value is
true.

For example:

    # sample if request header specifies known device identifier
    lambda {|env| KNOWN_DEVICES.include?(env['HTTP_X_DEVICE_ID'])}

### Kafka Tracer

Kafka tracer inherits from Tracer which is found in Finagle.  It allows using Kafka as
the transport instead of scribe.  If a config[:zookeeper] parameter is pass into the
initialization of the RackHandler, then the gem will use Kafka.  Hermann is the kafka
client library.  Hermann and the Scribe gems are optionally installed because we would
only use one of the other.  In your application, you will need to explicitly install
either Hermann or Scribe.

Caveat: Hermann is only usable from within Jruby, due to its implementation of zookeeper
based broker discovery being JVM based.

```
# zipkin-kafka-tracer requires at minimim Hermann 0.25.0 or later
  gem 'hermann', '~> 0.25'
# Install scribe
  gem 'scribe', "~> 0.2.4"
```

### JSON Tracer

Like the other tracers, it inherits from the Tracer found in Finagle.
If the configuration specifies a `json_api_host` then the gem will serialize the traces to JSON
and POST them to the defined host (the path to which the data is posted is `/api/v1/spans`).
If a `traces_buffer` value is provided it will buffer the traces call so as not to hammer your zipkin
instance. The default is `10`.
