require 'spec_helper'
require 'json'
require 'support/test_app'

# In this spec we are going to run two applications and check that they are creating traces
# And that the traces created by one application are sent to the other application

describe 'integrations' do
  before(:all) do
    @port1 = 4444
    @base_url1 = "http://localhost:#{@port1}"
    ru_location = File.join(`pwd`.chomp, 'spec', 'support', 'test_app_config.ru')
    @pipe1 = IO.popen("rackup #{ru_location} -p #{@port1}")

    @port2 = 4445
    @base_url2 = "http://localhost:#{@port2}"
    @pipe2 = IO.popen("rackup #{ru_location} -p #{@port2}")
    sleep(2)
    if RUBY_PLATFORM == 'java'
      sleep(20) #Jruby starts slow
    end

  end

  after(:each) do
    TestApp.clear_traces
  end

  after(:all) do
    Process.kill("KILL", @pipe1.pid)
    Process.kill("KILL", @pipe2.pid)
  end

  it 'has correct trace information on initial call to instrumented service' do
    response_str = `curl #{@base_url1}/hello_world`

    expect(response_str).to eq('Hello World')
    traces = TestApp.read_traces
    expect(traces.size).to eq(1)
    assert_level_0_trace_correct(traces)
  end

  it 'has correct trace information when the instrumented service calls itself, passing on trace information' do
    response_str = `curl #{@base_url1}/ouroboros?out_port=#{@port2}`

    expect(response_str).to eq('Ouroboros says Hello World')
    traces = TestApp.read_traces
    expect(traces.size).to eq(2)
    assert_level_0_trace_correct(traces)
    assert_level_1_trace_correct(traces)
  end

  # Assert that the first level of trace data is correct (or not!).
  # The trace_id and span_id should not be empty. The parent_span_id should be empty,
  # as a 0-level trace has no parent. The value of 'sampled' should be a boolean.
  def assert_level_0_trace_correct(traces)
    expect(traces[0]['trace_id']).not_to be_empty
    expect(traces[0]['parent_span_id']).to be_empty
    expect(traces[0]['span_id']).not_to be_empty
    expect(['1'].include?(traces[0]['sampled'])).to eq(true)
  end

  # Assert that the second level of trace data is correct (or not!).
  # The trace_id should be that of the 0th level trace_id. The first level parent_span_id should be
  # identical to the 0th level span_id. The first level span id should be a new id.
  def assert_level_1_trace_correct(traces)
    expect(traces[1]['trace_id']).to eq(traces[0]['trace_id'])
    expect(traces[1]['parent_span_id']).to eq(traces[0]['span_id'])
    expect(traces[1]['span_id']).not_to be_empty
    expect([traces[1]['trace_id'], traces[1]['parent_span_id']].include?(traces[1]['span_id'])).to be_falsey
    expect(['1'].include?(traces[1]['sampled'])).to eq(true)
  end
end
