require 'zipkin-tracer'
require 'sidekiq'
require_relative 'tracer_config'

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add ZipkinTracer::Sidekiq::Middleware, ZIPKIN_TRACER_CONFIG_WITH_WORKER
  end
end

class MyWorker
  include Sidekiq::Worker

  def perform
    sleep Random.rand(5)
    puts "Working hard after sleep"
  end
end
