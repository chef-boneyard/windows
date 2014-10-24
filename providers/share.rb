# Encoding: utf-8
# Author:: Dave Viebrock (<dave.viebrock@nordstrom.com>)
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

include Chef::Mixin::ShellOut
include Windows::Helper
include Windows::Share

# Support whyrun
def whyrun_supported?
  true
end

use_inline_resources

action :create do
  if @current_resource.exists
    Chef::Log.info "#{ @new_resource } shared folder already exists - nothing to do."
  else
    converge_by("Create #{ @new_resource }") do
      create_file_share
      new_resource.updated_by_last_action true
    end
  end
end

action :delete do
  if @current_resource.exists
    converge_by("Delete #{ @new_resource }") do
      delete_file_share
      new_resource.updated_by_last_action true
    end
  else
    Chef::Log.info "#{ @current_resource } doesn't exist - can't delete."
  end
end

def load_current_resource
  @current_resource = Chef::Resource::WindowsShare.new(@new_resource.share_name)
  @current_resource.name(@new_resource.share_name)
  @current_resource.folder_path(@new_resource.folder_path)
  @current_resource.permission(@new_resource.permission)
  @current_resource.exists = share_exists?(@current_resource.name)
end
