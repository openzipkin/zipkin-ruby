require 'json'
require 'faraday'

# This handy little app consumes both the rack and faraday zipkin middlewares.  We'll use
# this app to do some light integration testing on these middlewares.
#
class TestApp
  def call env
    store_current_trace_info # store so tests can look at historical data

    req = Rack::Request.new(env)
    if req.path == '/hello_world'
      [ 200, {'Content-Type' => 'application/json'}, ['Hello World'] ]
    elsif req.path == '/ouroboros' # this path will cause the TestApp to call the helloworld path of the app in certain port
      port = Rack::Utils.parse_query(env['QUERY_STRING'], "&")['out_port']
      base_url = "http://localhost:#{port}"
      conn = Faraday.new(:url => base_url) do |faraday|
        faraday.use ZipkinTracer::FaradayHandler
        faraday.adapter Faraday.default_adapter  # make requests with Net::HTTP
      end
      response = conn.get '/hello_world'

      [ 200, {'Content-Type' => 'application/json'}, ["Ouroboros says #{response.body}"]]
    else
      raise(RuntimeError, "Unrecognized path #{req.path}")
    end
  end

  def store_current_trace_info
    current_trace_info = {
      'trace_id'        => ZipkinTracer::TraceContainer.current.trace_id.to_s,
      'parent_span_id'  => ZipkinTracer::TraceContainer.current.parent_id.to_s,
      'span_id'         => ZipkinTracer::TraceContainer.current.span_id.to_s,
      'sampled'         => ZipkinTracer::TraceContainer.current.sampled.to_s
    }
    self.class.add_trace(current_trace_info.to_json)
  end

  # A 'scribe' to store our traces.
  class << self
    def read_traces
      file = File.open(traces_file_name, 'r')
      lines = file.readlines.map{ |l| JSON.parse(l) }
      file.close
      lines
    end

    def add_trace(trace)
      `touch traces.txt` # create the traces file if it doesn't exist
      open(traces_file_name, 'a') { |f|
        f.puts trace
      }
    end

    def clear_traces
      File.unlink traces_file_name
    end

    def traces_file_name
      'traces.txt'
    end
  end

end
