#
# Author:: Seth Chisamore (<schisamo@chef.io>)
# Cookbook:: windows
# Resource:: feature
#
# Copyright:: 2011-2016, Chef Software, Inc.
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

# why is this here?
include Windows::Helper

actions :install, :remove, :delete
default_action :install

provides :windows_feature_dism
provides :windows_feature do
  ::File.exist?(locate_sysnative_cmd('dism.exe'))
end

attribute :feature_name, kind_of: String, name_attribute: true
attribute :source, kind_of: String
attribute :all, kind_of: [TrueClass, FalseClass], default: false
