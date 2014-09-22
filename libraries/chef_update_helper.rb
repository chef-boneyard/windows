#
# Author:: Jay Mundrawala (<jdm@getchef.com>)
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

require 'chef/win32/api/installer' if Chef::Platform::windows?
require 'rubygems'

module MsiInstallerFunctions
  extend Chef::ReservedNames::Win32::API::Installer if Chef::Platform::windows?
end

module Windows
  module ChefUpdateHelper
    class UpgradeRequested < RuntimeError; end

    def self.windows_path(path)
      if path.start_with? '/'
        path = "#{ENV['SystemDrive']}/#{path}"
      end
      path = path.gsub(::File::SEPARATOR, ::File::ALT_SEPARATOR || '\\')
    end

    def self.can_upgrade_to?(source)
      source = windows_path(source)
      current_version = Chef::VERSION
      msi_version = MsiInstallerFunctions.get_product_property(source, 'ProductVersion').strip.gsub(/-\d+$/,'')
      Chef::Log.debug("Found chef #{current_version} installed. Asked to upgrade to #{msi_version}.")
      Gem::Version.new(msi_version) > Gem::Version.new(current_version)
    end

    def self.format_start_day(month, day, year)
      '%02d/%02d/%04d' % [month, day, year]
    end

    def self.format_start_time(hour, min)
      '%02d:%02d' % [hour, min]
    end
  end
end
