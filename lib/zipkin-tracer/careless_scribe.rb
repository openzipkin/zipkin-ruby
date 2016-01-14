# Copyright 2012 Twitter Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'scribe'
require 'finagle-thrift' #depends on the thift gem
require 'sucker_punch'

module ScribeThrift
  # This is here just for the monkey patching
  class Client
    # This method in the original class was both sending and receiving logs.
    # The original class: https://github.com/twitter/scribe/blob/master/vendor/gen-rb/scribe.rb
    # Receiving logs may take even several seconds, depending on the buffering of the collector.
    # We are just sending and forgetting here, we do not really care about the result
    def Log(messages)
      send_Log(messages)
      0 # 0 means success , the original code called recv_Log()
    end
  end
end

# SuckerPunch creates a queue and a thread pool to work on jobs on the queue
# calling perform adds the code to the queue
class AsyncScribe
  include SuckerPunch::Job

  PROTOCOL_TIMEOUT = 10  # If the timeout is low, the protocol will lose spans when collector is not fast enough
  CATEGORY = 'ruby'       # Thrift-client already uses this as default, seems to not affect anything
  ADD_NEWLINES_TO_MESSAGES = true  # True is the default in Thrift-client, seems a necessary internal hack

  def perform(server_address, *args)
    # May seem wasteful to open a new connection per each span but the way the scribe is done
    # it is difficult to ensure there will be no threading issues unless we create here the connection
    scribe = Scribe.new(server_address, CATEGORY, ADD_NEWLINES_TO_MESSAGES, timeout: PROTOCOL_TIMEOUT)
    scribe.log(*args)
  rescue ThriftClient::NoServersAvailable, Thrift::Exception
    # I couldn't care less
  end
end

# Scribe which rescue thrift errors to avoid them to raise to the client
class CarelessScribe
  def initialize(scribe_server_address)
    @server_address = scribe_server_address
  end

  def log(*args)
    AsyncScribe.new.async.perform(@server_address, *args)
  end

  def batch(&block)
    yield   #We just yield here
    # the block finagle-thrift-1.4.1/lib/finagle-thrift/tracer.rb flush! method will call log also.
  rescue ThriftClient::NoServersAvailable, Thrift::Exception
    # I couldn't care less
  end
end
