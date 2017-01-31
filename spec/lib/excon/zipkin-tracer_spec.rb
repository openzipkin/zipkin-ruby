require 'spec_helper'
require 'zipkin-tracer/zipkin_null_tracer'
require 'lib/middleware_shared_examples'

describe ZipkinTracer::ExconHandler do
  # returns the request headers
  def process(body, url, headers = {})
    stub_request(:post, url).to_return(status: 200, body: body, headers: headers)
    ENV['ZIPKIN_SERVICE_NAME'] = service_name

    connection = Excon.new(url.to_s,
                           body: body,
                           method: :post,
                           headers: headers,
                           middlewares: [ZipkinTracer::ExconHandler] + Excon.defaults[:middlewares]
                          )
    connection.request

    request_headers = nil
    expect(a_request(:post, url).with { |req| 
      # Webmock 'normalizes' the headers. E.g: X-B3-TraceId becomes X-B3-Traceid.
      # See here:
      # https://github.com/bblimke/webmock/blob/a4aad22adc622699a8ea14c70d04acef8f67a512/lib/webmock/util/headers.rb#L9
      # So here, headers are manually fetched.
      request_headers = {
        'X-B3-TraceId' => req.headers['X-B3-Traceid'],
        'X-B3-ParentSpanId' => req.headers['X-B3-Parentspanid'],
        'X-B3-SpanId' => req.headers['X-B3-Spanid'],
        'X-B3-Sampled' => req.headers['X-B3-Sampled'],
        'X-B3-Flags' => req.headers['X-B3-Flags']
      }
    }).to have_been_made

    request_headers
  end

  context 'middleware configured (without service_name)' do
    let(:service_name) { 'service' }

    context 'request with string URL' do
      let(:url) { raw_url }

      include_examples 'can make requests'
    end

    context 'request with pre-parsed URL' do
      let(:url) { URI.parse(raw_url) }

      include_examples 'can make requests'
    end
  end

  context 'configured with service_name "foo"' do
    let(:service_name) { 'foo' }

    context 'request with pre-parsed URL' do
      let(:url) { URI.parse(raw_url) }

      include_examples 'can make requests'
    end
  end
end
