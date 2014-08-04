#
# Author:: Adam Edwards (<adamed@getchef.com>)
#
# Copyright:: 2014, Chef Software, Inc.
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

#
# Allow libraries to load the wmi-lite gem dependency they require
# since there is no recipe execution of the chef_gem resource
# that can be used when libraries are loaded ahead of resource 
# execution.
# 
begin
  require 'wmi-lite'
rescue LoadError
  empty_node = Chef::Node.new
  empty_events = Chef::EventDispatch::Dispatcher.new
  run_context = Chef::RunContext.new(empty_node, {}, empty_events)

  wmi_gem = Chef::Resource::ChefGem.new('wmi-lite', run_context)
  wmi_gem.run_action(:install)

  require 'wmi-lite'
end

