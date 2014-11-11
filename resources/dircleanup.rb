# Encoding: utf-8
# Author:: Dave Viebrock (<dave.viebrock@nordstrom.com>) with

# Cookbook Name:: windows
# Provider:: windows_dircleanup
#
# Copyright:: 2014, Nordstrom, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

actions :cleanup
default_action :cleanup

attribute :directory, kind_of: String
attribute :age, kind_of: String, default: '15'

attr_accessor :exists
