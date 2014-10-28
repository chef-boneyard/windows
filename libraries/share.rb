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

module Windows
  module Share

    def share_exists?(share_name)
      share_name = new_resource.share_name
      Chef::Log.debug "Checking for existence of shared folder: #{share_name}"
      @exists ||= begin
        cmd = shell_out("net.exe share #{share_name}", returns: [0])
        cmd.stderr.empty? && cmd.stdout.include?(share_name)
      end
    end

    def create_file_share
      share_name = new_resource.share_name
      folder_path = new_resource.folder_path
      group = new_resource.group
      permission = new_resource.permission

      Chef::Log.debug "Creating shared folder: #{share_name}"
      shell_out("net.exe share #{share_name}=#{folder_path} /Grant:#{group},#{permission}", returns: [0])
    end

    def delete_file_share
      share_name = new_resource.share_name
      folder_path = new_resource.folder_path

      Chef::Log.debug "Deleting shared folder: #{share_name}"
      shell_out("net.exe share #{share_name} /delete", returns: [0])
    end
  end
end
