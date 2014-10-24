# Encoding: utf-8
# Author:: Dave Viebrock (<dave.viebrock@nordstrom.com>) with
# assistance gratefully accepted from James Fitzgibbon and Doug Ireton

# Cookbook Name:: windows
# Provider:: windows_share
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

actions :create, :delete
default_action :create

attribute :share_name, kind_of: String, required: true
attribute :folder_path, kind_of: String, required: true
attribute :group, kind_of: String, default: 'Everyone'
attribute :permission, kind_of: String, default: 'Change', equal_to: %w(Full Change Read)

attr_accessor :exists
