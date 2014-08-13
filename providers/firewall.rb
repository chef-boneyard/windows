#
# Author:: Derek Groh (<dgroh@arch.tamu.edu>)
# Cookbook Name:: windows
# Provider:: firewall
#
# Copyright:: 2014, Texas A&M University
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

action :create do
  if exists?
    new_resource.updated_by_last_action(false)
  else
    cmd = "netsh advfirewall add rule name=\"#{new_resource.rule_name}\" dir=\"#{new_resource.direction}\" action=\"#{new_resource.behavior}\""
    
    new_resource.options.each do |option, value|
      cmd << "#{option}=#{value}"
    end

    new_resource.updated_by_last_action(true)
  end
end

action :delete do
  if exists?
    new_resource.updated_by_last_action(false)
  else
    cmd = "netsh advfirewall delete rule name=\"#{new_resource.rule_name}\""
    
    # List of additional options: http://technet.microsoft.com/en-us/library/dd734783(v=ws.10).aspx#BKMK_3_delete
    new_resource.options.each do |option, value|
      cmd << "#{option}=#{value}"
    end
  end

  new_resource.updated_by_last_action(true)
end

action :set do
  if exists?
    new_resource.updated_by_last_action(false)
  else
    cmd = "netsh advfirewall set rule name=\"#{new_resource.rule_name}\""
    
    # List of additional options: http://technet.microsoft.com/en-us/library/dd734783(v=ws.10).aspx#BKMK_3_set
    new_resource.options.each do |option, value|
      cmd << "#{option}=#{value}"
    end
  end

  new_resource.updated_by_last_action(true)
end
