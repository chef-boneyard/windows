#
# Author:: Tim Smith (<tsmith@chef.io>)
# Cookbook:: windows
# Library:: feature_cache_ps
#
# Copyright:: 2018, Chef Software, Inc.
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

require 'chef/mixin/shell_out'
require 'chef/node/attribute_collections'
require 'chef/json_compat'

class PSCache
  include Singleton
  include Chef::Mixin::ShellOut

  # fetch the list of available feature names from Get-WindowsFeature cmdlet and parse the JSON
  def parsed_feature_list
    # Grab raw feature information from Get-WindowsFeature cmdlet
    raw_list_of_features = if Chef.node['platform_version'][/^(\d+\.\d+)/, 1].to_f < 6.2
                             powershell_out!('Import-Module ServerManager; Get-WindowsFeature | Select-Object -Property Name,InstallState | ConvertTo-Json -Compress', timeout: new_resource.timeout).stdout
                           else
                             powershell_out!('Get-WindowsFeature | Select-Object -Property Name,InstallState | ConvertTo-Json -Compress', timeout: new_resource.timeout).stdout
                           end

    Chef::JSONCompat.from_json(raw_list_of_features)
  end

  # Create a hash with 'disabled', 'enabled', and 'removed' arrays and parse the
  # features into those arrays. We do this because getting a list of features with
  # Powershell takes at least a second  and this data will be persisted across
  # multiple resource runs which gives us a much faster run when no features
  # actually need to be installed / removed.
  # @return [Hash] hash containing 'enabled', 'disabled' and 'removed' arrays
  def data
    @data ||= begin
      data = Mash.new
      data['enabled'] = []
      data['disabled'] = []
      data['removed'] = []

      parsed_feature_list.each do |feature_details_raw|
        case feature_details_raw['InstallState']
        when 5 # matches 'Removed' InstallState
          data['removed'] << feature_details_raw['Name'].downcase # lowercase so we can compare properly
        when 1, 3 # matches 'Installed' or 'InstallPending' states
          data['enabled'] << feature_details_raw['Name'].downcase # lowercase so we can compare properly
        when 0, 2 # matches 'Available' or 'UninstallPending' states
          data['disabled '] << feature_details_raw['Name'].downcase # lowercase so we can compare properly
        end
      end

      data
    end
  end

  # simple forces the data to regenerate the mash
  # @return [void]
  def reset
    @data = nil
  end
end
