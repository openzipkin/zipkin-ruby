#0.6.1
Relax constraint on Rack from ~>1.6 to ~>1.3

#0.6
New configuration option :logger to setup a logger for error messages
The Zipkin Rack middleware will not raise an error if sending information to Zipkin raises an error

#0.5.1
The Zipkin Rack middleware will not raise an error if sending information to Zipkin raises an error
Integration specs to make sure information is properly passed when using Rack middleware together with Faraday's

# 0.5.0
Added Faraday middleware to the repo

# 0.4.0
Use Thread safe Finagle version to store the traces
