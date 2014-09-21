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
    def can_upgrade_to?(source)
      product_code = MsiInstallerFunctions.get_product_property(source, 'ProductCode').strip
      current_version = MsiInstallerFunctions.get_installed_version(product_code).strip
      msi_version = MsiInstallerFunctions.get_product_property(source, 'ProductVersion').strip
      Gem::Version.new(msi_version) > Gem::Version.new(current_version)
    end
  end
end

Chef::Recipe.send(:include, Windows::ChefUpdateHelper)
