# 0.8.1
Set caller service name using domain environment variable. If the value
is not set, it will fall back to the configuration file default.

# 0.8.0
To proper follow the correct spec, now the annotations cr/cs set the local service as servicename
Added a 'sa' annotation to indicate the remote service servicename

# 0.7.3
Send method name (get, post, etc) as lowercase (zipkin > 1.22 expect them lowercase)

# 0.7.2
Rescue possible errors when lookup of the hostname fails

# 0.7.1
Remove Scribe from direct dependencies list

#0.7
The ruby client does not wait to receive ACK from the collector. Just send traces
Connecting to the collector now happens in a different thread
The server annotations will not add information about the URL hit if hit by a zipkin enabled client

#0.6.3
Properly pop the Id from the traces stacks when finishing the Faraday tracer

#0.6.2
Do not trace requests if the current application will not serve them.

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
