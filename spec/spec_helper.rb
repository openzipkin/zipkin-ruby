if ENV['COV']
  require 'simplecov'
  SimpleCov.start
end

require 'zipkin-tracer'
require 'timecop'
require 'webmock/rspec'
require 'sucker_punch/testing/inline'

RSpec.configure do |config|
  config.order = :random

  config.after(:each) do
    Timecop.return
    WebMock.reset!
  end
end
