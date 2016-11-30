require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'zipkin-tracer'
require 'benchmark'
require 'benchmark/ips'
require 'faraday'
require 'rack/mock'
require 'rbtrace'
require 'tempfile'

def add_rspec_options(options=[])
  if RUBY_PLATFORM == 'java'
    options << '--tag ~platform:mri'
  else
    options << '--tag ~platform:java'
  end
  return options
end

RSpec::Core::RakeTask.new(:spec) do |r|
  r.rspec_opts = add_rspec_options
end

task :default => :spec


# Used to test a completely minimum middleware, no zipkin.
class EmptyMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    if @app.respond_to?(:call)
      status, headers, body = @app.call(env)
    else
      [200, {}, 'Hello world']
    end
  end
end


# Used to mock a middleware which uses Faraday.
# Note that we are creating fake objects pretending to be Faraday for speed.
class FaradayMiddleware
  def initialize
    response_env = { status: 200 }
    @env = {
        method: :post,
        url: 'http://www.this_is_not_really_called.com',
        body: 'majere',
        request_headers: Faraday::Utils::Headers.new({}),
      }
      @app = lambda { |env| ResponseObject.new(@env, response_env) }
      @middleware = ZipkinTracer::FaradayHandler.new(@app)
  end

  def call(_env)
    @middleware.call(@env)
  end

  private

  class ResponseObject
    attr_reader :env

    def initialize(env, response_env)
      @env = env
      @response_env = response_env
    end

    def on_complete
      yield @response_env
      self
    end
  end
end

desc "Runs a zipkin middleware once."
task :run_once do
  empty_app = EmptyMiddleware.new(nil)
  app = FaradayMiddleware.new

  logger = Logger.new(Tempfile.new('fakelog'))
  null_configuration = { logger: logger, sample_rate: 1}
  null_tracer_rack = ZipkinTracer::RackHandler.new(app, null_configuration)
  env = Rack::MockRequest.env_for('/path', {})

  sleep(10)
  null_tracer_rack.call(env)
end

# This task is used to help development of ZipkinTracer.
# It benchmark the relative performance of the different tracers.
desc "Runs benchmarks for ZipkinTracer."
task :benchmark do
  logger = Logger.new(Tempfile.new('fakelog'))
  fake_url = 'http://www.google.com' #resolve but unable to send I hope!

  empty_app = EmptyMiddleware.new(nil)

  null_configuration = { sample_rate: 1 }
  json_configuration = null_configuration.merge(json_api_host: fake_url)
  logger_configuration = null_configuration.merge(logger: logger)

  # We create a different faraday middleware per rack middleware below because
  # both middlewares share the same tracer. So they need to be created in pairs.
  empty_rack = EmptyMiddleware.new(empty_app)
  null_tracer_rack = ZipkinTracer::RackHandler.new(empty_app, null_configuration)
  null_faraday_app = FaradayMiddleware.new
  null_tracer_faraday_rack = ZipkinTracer::RackHandler.new(null_faraday_app, null_configuration)
  json_tracer_rack = ZipkinTracer::RackHandler.new(empty_app, json_configuration)
  json_faraday_app = FaradayMiddleware.new
  json_tracer_faraday_rack = ZipkinTracer::RackHandler.new(json_faraday_app, json_configuration)
  logger_tracer_rack = ZipkinTracer::RackHandler.new(empty_app, logger_configuration)
  log_faraday_app = FaradayMiddleware.new
  logger_tracer_faraday_rack = ZipkinTracer::RackHandler.new(log_faraday_app, logger_configuration)

  env = Rack::MockRequest.env_for('/path', {})

  Benchmark.ips do |bm|
  # bm.report("No rack middleware") { empty_rack.call(env) } # Uncomment if curious
    bm.report("NullTracer") { null_tracer_rack.call(env) }
    bm.report("NullTracer + Faraday") { null_tracer_faraday_rack.call(env) }
    bm.report("JSONTracer") { json_tracer_rack.call(env) }
    bm.report("JSONTracer + Faraday") { json_tracer_faraday_rack.call(env) }
    bm.report("Logging Tracer") { logger_tracer_rack.call(env) }
    bm.report("Logging Tracer + Faraday") { logger_tracer_faraday_rack.call(env) }
    bm.compare!
  end

  puts "i/s means the number of times the middleware can be called per second"

end
