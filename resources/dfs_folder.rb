#
# Author:: Jason Field
# Cookbook Name:: windows
# Resource:: dfs_folder
#
# Copyright:: 2018, Calastone Ltd.
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
# Sets up a DFS Folder

property :folder_path, String, name_property: true
property :namespace_name, String, required: true
property :target_path, String
property :description, String

action :install do
  raise 'target_path is required for install' unless property_is_set?(:target_path)
  raise 'description is required for install' unless property_is_set?(:description)
  powershell_script 'Create or Update DFS Folder' do
    code <<-EOH

      $needs_creating = (Get-DfsnFolder -Path '\\\\#{ENV['COMPUTERNAME']}\\#{new_resource.namespace_name}\\#{new_resource.folder_path}' -ErrorAction SilentlyContinue) -eq $null
      if (!($needs_creating))
      {
        Remove-DfsnFolder -Path '\\\\#{ENV['COMPUTERNAME']}\\#{new_resource.namespace_name}\\#{new_resource.folder_path}' -Force
      }
        New-DfsnFolder -Path '\\\\#{ENV['COMPUTERNAME']}\\#{new_resource.namespace_name}\\#{new_resource.folder_path}' -TargetPath '#{new_resource.target_path}' -Description '#{new_resource.description}'
    EOH
    not_if "return ((Get-DfsnFolder -Path '\\\\#{ENV['COMPUTERNAME']}\\#{new_resource.namespace_name}\\#{new_resource.folder_path}' -ErrorAction SilentlyContinue).Description -eq '#{new_resource.description}' -and  (Get-DfsnFolderTarget -Path '\\\\#{ENV['COMPUTERNAME']}\\#{new_resource.namespace_name}\\#{new_resource.folder_path}').TargetPath -eq '#{new_resource.target_path}' )"
  end
end

action :delete do
  powershell_script 'Delete DFS Namespace' do
    code <<-EOH
      Remove-DfsnFolder -Path '\\\\#{ENV['COMPUTERNAME']}\\#{new_resource.namespace_name}\\#{new_resource.folder_path}' -Force
      EOH
    only_if "return ((Get-DfsnFolder -Path '\\\\#{ENV['COMPUTERNAME']}\\#{new_resource.namespace_name}\\#{new_resource.folder_path}' ) -ne $null)"
  end
end
