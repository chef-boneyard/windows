# Encoding: utf-8
# Author:: Dave Viebrock (<dave.viebrock@nordstrom.com>)
# Cookbook Name:: windows
# Provider:: windows_dep
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
  module Dep

    def bcdedit
      @bcdedit ||= begin
        locate_sysnative_cmd("bcdedit.exe")
      end
    end

    def dep_exists?(approach)
        approach = new_resource.approach
        Chef::Log.debug "Checking for existing DEP approach: #{approach}"
        @exists ||= begin
          cmd = shell_out!(bcdedit, returns: [0])
          Chef::Log.debug "DEP query value is #{cmd.stdout}"
          cmd.stderr.empty? && cmd.stdout.include?("#{approach}")
        end
      end

    def set_dep_approach
      approach = new_resource.approach
      Chef::Log.debug "Setting DEP approach required by recipe: #{approach}"
      shell_out!("#{bcdedit} /set nx #{approach}", returns: [0])
    end
  end
end
