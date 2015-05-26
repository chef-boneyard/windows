#
# Author:: Venkat Naidu (naiduvenkat@gmail.com)
# Cookbook Name:: windows
# Provider:: share
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


require 'chef/mixin/shell_out'

include Chef::Mixin::ShellOut
include Windows::Helper

def load_current_resource
  @current_resource = Chef::Resource::WindowsShare.new(@new_resource.name)
  @current_resource.name(@new_resource.name)
  @current_resource.user(@new_resource.user)
  @current_resource.path(@new_resource.path)
  @current_resource.access(@new_resource.access)

  @current_resource
end

action :create do
  cmd = "net share " + @current_resource.name + "=" + @current_resource.path + " /GRANT:" + @current_resource.user + ",#{access_type_template}"
  shell_out!(cmd)
  @new_resource.updated_by_last_action(true)
  Chef::Log.info("Share created")
end

def access_type_template
  case access_type
  when :read
    "READ"
  when :change
    "CHANGE"
  when :full
    "FULL"
  else
  end
end

def access_type
  @current_resource.access
end
