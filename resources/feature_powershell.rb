#
# Author:: Greg Zapp (<greg.zapp@gmail.com>)
#
# Cookbook:: windows
# Resource:: feature_powershell
#
# Copyright:: 2015-2018, Chef Software, Inc
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

property :feature_name, [Array, String], coerce: proc { |x| Array(x) }, name_property: true
property :source, String
property :all, [true, false], default: false
property :timeout, Integer, default: 600
property :management_tools, [true, false], default: false

include Chef::Mixin::PowershellOut

action :install do
  reload_cached_powershell_data unless node['powershell_features_cache']
  fail_if_unavailable # fail if the features don't exist
  fail_if_removed # fail if the features are in removed state

  reload_cached_powershell_data unless node['powershell_features_cache']

  Chef::Log.debug("Windows features needing installation: #{features_to_install.empty? ? 'none' : features_to_install.join(',')}")
  unless features_to_install.empty?
    converge_by("install Windows feature#{'s' if features_to_install.count > 1} #{features_to_install.join(',')}") do
      addsource = new_resource.source ? "-Source \"#{new_resource.source}\"" : ''
      addall = new_resource.all ? '-IncludeAllSubFeature' : ''
      addmanagementtools = new_resource.management_tools ? '-IncludeManagementTools' : ''
      cmd = if node['os_version'].to_f < 6.2
              powershell_out!("#{install_feature_cmdlet} #{features_to_install.join(',')} #{addall}", timeout: new_resource.timeout)
            else
              powershell_out!("#{install_feature_cmdlet} #{features_to_install.join(',')} #{addsource} #{addall} #{addmanagementtools}", timeout: new_resource.timeout)
            end
      Chef::Log.info(cmd.stdout)

      reload_cached_powershell_data # Reload cached powershell feature state
    end
  end
end

action :remove do
  reload_cached_powershell_data unless node['powershell_features_cache']

  Chef::Log.debug("Windows features needing removal: #{features_to_remove.empty? ? 'none' : features_to_remove.join(',')}")

  unless features_to_remove.empty?
    converge_by("remove Windows feature#{'s' if features_to_remove.count > 1} #{features_to_remove.join(',')}") do
      cmd = powershell_out!("#{remove_feature_cmdlet} #{features_to_remove.join(',')}", timeout: new_resource.timeout)
      Chef::Log.info(cmd.stdout)

      reload_cached_powershell_data # Reload cached powershell feature state
    end
  end
end

action :delete do
  fail_if_delete_unsupported

  reload_cached_powershell_data unless node['powershell_features_cache']

  fail_if_unavailable # fail if the features don't exist

  Chef::Log.debug("Windows features needing deletion: #{features_to_delete.empty? ? 'none' : features_to_delete.join(',')}")

  unless features_to_delete.empty?
    converge_by("delete Windows feature#{'s' if features_to_delete.count > 1} #{features_to_delete.join(',')} from the image") do
      cmd = powershell_out!("Uninstall-WindowsFeature #{features_to_delete.join(',')} -Remove", timeout: new_resource.timeout)
      Chef::Log.info(cmd.stdout)

      reload_cached_powershell_data # Reload cached powershell feature state
    end
  end
end

action_class do
  def install_feature_cmdlet
    node['os_version'].to_f < 6.2 ? 'Import-Module ServerManager; Add-WindowsFeature' : 'Install-WindowsFeature'
  end

  def remove_feature_cmdlet
    node['os_version'].to_f < 6.2 ? 'Import-Module ServerManager; Remove-WindowsFeature' : 'Uninstall-WindowsFeature'
  end

  # @return [Array] features the user has requested to install which need installation
  def features_to_install
    # the intersection of the features to install & disabled features are what needs installing
    @install ||= new_resource.feature_name & node['powershell_features_cache']['disabled']
  end

  # @return [Array] features the user has requested to remove which need removing
  def features_to_remove
    # the intersection of the features to remove & enabled features are what needs removing
    @remove ||= new_resource.feature_name & node['powershell_features_cache']['enabled']
  end

  # @return [Array] features the user has requested to delete which need deleting
  def features_to_delete
    # the intersection of the features to remove & enabled/disabled features are what needs removing
    @remove ||= begin
      all_available = node['powershell_features_cache']['enabled'] +
                      node['powershell_features_cache']['disabled']
      new_resource.feature_name & all_available
    end
  end

  # if any features are not supported on this release of Windows or
  # have been deleted raise with a friendly message. At one point in time
  # we just warned, but this goes against the behavior of ever other package
  # provider in Chef and it isn't clear what you'd want if you passed an array
  # and some features were available and others were not.
  # @return [void]
  def fail_if_unavailable
    all_available = node['powershell_features_cache']['enabled'] +
                    node['powershell_features_cache']['disabled'] +
                    node['powershell_features_cache']['removed']

    # the difference of desired features to install to all features is what's not available
    unavailable = (new_resource.feature_name - all_available)
    raise "The Windows feature#{'s' if unavailable.count > 1} #{unavailable.join(',')} #{unavailable.count > 1 ? 'are' : 'is'} not available on this version of Windows. Run 'Get-WindowsFeature' to see the list of available feature names." unless unavailable.empty?
  end

  # run Get-WindowsFeature to get a list of all available features and their state
  # and save that to the node at node.override level.
  # @return [void]
  def reload_cached_powershell_data
    Chef::Log.debug('Caching Windows features available via Get-WindowsFeature.')
    node.override['powershell_features_cache'] = Mash.new
    node.override['powershell_features_cache']['enabled'] = []
    node.override['powershell_features_cache']['disabled'] = []
    node.override['powershell_features_cache']['removed'] = []

    # Grab raw feature information from dism command line
    raw_list_of_features = if node['os_version'].to_f < 6.2
                             powershell_out('Import-Module ServerManager; Get-WindowsFeature | Select-Object -Property Name,InstallState | ConvertTo-Json -Compress', timeout: new_resource.timeout).stdout
                           else
                             powershell_out('Get-WindowsFeature | Select-Object -Property Name,InstallState | ConvertTo-Json -Compress', timeout: new_resource.timeout).stdout
                           end

    # Split stdout into an array by windows line ending
    features_list = JSON.parse(raw_list_of_features)

    features_list.each do |feature_details_raw|
      case feature_details_raw['InstallState']
      when 5 # matches 'Removed' InstallState
        add_to_feature_mash('removed', feature_details_raw['Name'])
      when 1 # matches 'Installed' InstallState
        add_to_feature_mash('enabled', feature_details_raw['Name'])
      when 0 # matches 'Available' InstallState
        add_to_feature_mash('disabled', feature_details_raw['Name'])
      end
    end
    Chef::Log.debug("The powershell cache contains\n#{node['powershell_features_cache']}")
  end

  # add the features values to the appropriate array
  def add_to_feature_mash(feature_type, feature_details)
    node.override['powershell_features_cache'][feature_type] << feature_details
  end

  # Fail if any of the packages are in a removed state
  # @return [void]
  def fail_if_removed
    return if new_resource.source # if someone provides a source then all is well
    if node['os_version'].to_f > 6.2
      return if registry_key_exists?('HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Servicing') && registry_value_exists?('HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Servicing', name: 'LocalSourcePath') # if source is defined in the registry, still fine
    end
    removed = new_resource.feature_name & node['powershell_features_cache']['removed']
    raise "The Windows feature#{'s' if removed.count > 1} #{removed.join(',')} #{removed.count > 1 ? 'are' : 'is'} have been removed from the host and cannot be installed." unless removed.empty?
  end

  # Fail unless we're on windows 8+ / 2012+ where deleting a feature is supported
  def fail_if_delete_unsupported
    raise Chef::Exceptions::UnsupportedAction, "#{self} :delete action not support on Windows releases before Windows 8/2012. Cannot continue!" unless node['platform_version'].to_f >= 6.2
  end
end
