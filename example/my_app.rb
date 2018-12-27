require 'sinatra/base'
require 'faraday'
require 'zipkin-tracer'
require_relative 'my_worker'

class MyApp < Sinatra::Base
  def conn
    @@faraday ||= Faraday.new(url: 'https://xkcd.com/') do |faraday|
      faraday.use ZipkinTracer::FaradayHandler
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
    end
  end

  get '/faraday' do
    response = conn.get '/info.0.json'
    content_type 'application/json'
    response.body
  end

  get '/sidekiq' do
    ::MyWorker.perform_async
    'Worker started'
  end

  get '/local_tracing' do
    ZipkinTracer::TraceClient.local_component_span('Example process') do |ztc|
      ztc.record 'Sleep for some time'
      ztc.record_tag 'duration', '3'
      sleep 3 # You can do anything here to get record into span
    end
    'Server just slept for 3 sec'
  end

  get '/' do
    erb <<~hello
      Hello and welcome to Ruby Zipkin tracer example.
      From here:
      <ul>
        <li>head to <a href='/faraday'>/faraday</a> to trace an outgoing request.</li>
        <li>head to <a href='/sidekiq'>/sidekiq</a> to trace a sidekiq worker.</li>
        <li>head to <a href='/local_tracing'>/local_tracing</a> to trace an outgoing request.</li>
      </ul>
    hello
  end
end
