if ENV['COV']
  require 'simplecov'
  SimpleCov.start do
    add_filter "/spec/"
  end
end

require 'zipkin-tracer'
require 'timecop'
require 'webmock/rspec'
require 'sucker_punch/testing/inline'

RSpec.configure do |config|
  config.order = :random
  RSpec::Mocks.configuration.allow_message_expectations_on_nil = true

  config.after(:each) do
    Timecop.return
    WebMock.reset!
  end
end
