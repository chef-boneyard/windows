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
  module Dircleanup

    def dir
      @dir ||= begin
        locate_sysnative_cmd("dir.exe")
      end
    end

    def directory_exists?(directory)
        directory = new_resource.directory
        Chef::Log.debug "Checking for existing directory: #{directory}"
        @exists ||= begin
          cmd = shell_out!("#{dir} #{directory}", returns: [0])
          Chef::Log.debug "Directory query value is: #{cmd.stdout}"
          cmd.stderr.empty? && cmd.stdout.include?("#{directory}")
        end
      end

    def cleanup_directory
      directory = new_resource.directory
      age = new_resource.age
      Chef::Log.info "Cleaning up files older than #{age} days in directory specified recipe: #{directory}"
      cmd = shell_out!("forfiles -p #{directory} -s -d -#{age} -c \"cmd /c del /Q @file\" & exit /b 0", returns: [0])
      cmd = shell_out!("forfiles -p #{directory} -s -d -#{age} -c \"cmd /c IF @ISDIR == TRUE rmdir /Q @PATH\" & exit /b 0", returns: [0])
    end
  end
end
