#
# Author:: Seth Chisamore (<schisamo@opscode.com>)
# Cookbook Name:: windows
# Recipe:: restart_handler
#
# Copyright:: 2011, Opscode, Inc.
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

remote_directory node['chef_handler']['handler_path'] do
  source 'handlers'
  recursive true
  action :create
end

# This was primarily done to prevent others from having to stub
# `include_recipe "reboot_handler"` inside ChefSpec.  ChefSpec
# doesn't seem to handle the following well on convergence.
ruby_block "load namespace" do
  block do
    begin
      require "#{node['chef_handler']['handler_path']}/windows_reboot_handler"
    rescue LoadError
      log 'Unable to require the windows reboot handler!'
    end
  end
end

chef_handler 'WindowsRebootHandler' do
  source "#{node['chef_handler']['handler_path']}/windows_reboot_handler.rb"
  arguments node['windows']['allow_pending_reboots']
  supports :report => true, :exception => node['windows']['allow_reboot_on_failure']
  action :enable
end
