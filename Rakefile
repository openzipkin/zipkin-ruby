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

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

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
