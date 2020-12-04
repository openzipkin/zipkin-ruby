#!/bin/sh

set -ue

# This script deploys a release version.
#
# See [README.md] for an explanation of this and how CI should use it.
version=${1?version is required. ex 0.2.3}

export BUNDLE_GEMFILE=gemfiles/faraday_1.x.gemfile
build-bin/gem/gem_push zipkin-tracer ZipkinTracer ${version}
