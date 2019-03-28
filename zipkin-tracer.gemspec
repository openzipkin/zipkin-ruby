# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'zipkin-tracer/version'

Gem::Specification.new do |s|
  s.name                      = 'zipkin-tracer'
  s.version                   = ZipkinTracer::VERSION
  s.authors                   = ['Franklin Hu', 'R Tyler Croy', 'James Way', 'Jordi Polo', 'Julien Feltesse', 'Scott Steeg']
  s.email                     = ['franklin@twitter.com', 'tyler@monkeypox.org', 'jamescway@gmail.com', 'jcarres@mdsol.com', 'jfeltesse@mdsol.com', 'ssteeg@mdsol.com']
  s.homepage                  = 'https://github.com/openzipkin/zipkin-tracer'
  s.summary                   = 'Ruby tracing via Zipkin'
  s.description               = 'Adds tracing instrumentation for ruby applications'
  s.license                   = 'Apache-2.0'

  s.required_rubygems_version = '>= 1.3.5'
  s.required_ruby_version     = '>= 2.3.0'

  s.files                     = Dir.glob('{bin,lib}/**/*')
  s.require_path              = 'lib'

  s.add_dependency 'faraday', '~> 0.8'
  s.add_dependency 'rack', '>= 1.0'
  s.add_dependency 'sucker_punch', '~> 2.0'

  s.add_development_dependency 'excon', '~> 0.53'
  s.add_development_dependency 'rspec', '~> 3.8'
  s.add_development_dependency 'rack-test', '~> 1.1'
  s.add_development_dependency 'rake', '~> 10.0'
  s.add_development_dependency 'timecop', '~> 0.8'
  s.add_development_dependency 'webmock', '~> 3.0'
  s.add_development_dependency 'simplecov', '~> 0.16'
end
