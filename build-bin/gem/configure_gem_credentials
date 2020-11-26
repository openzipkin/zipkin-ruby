#!/bin/sh
#
# Copyright 2014-2020 The OpenZipkin Authors
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except
# in compliance with the License. You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License
# is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
# or implied. See the License for the specific language governing permissions and limitations under
# the License.
#

set -ue

# This script configures rubygems_api_key needed to for gem-push

credentials_file="${HOME}/.gem/credentials"
mkdir -p "$(dirname "${credentials_file}")"
cat > "${credentials_file}" <<-EOF
---
:rubygems_api_key: ${RUBYGEMS_API_KEY}
EOF
chmod 0600 "${credentials_file}"
