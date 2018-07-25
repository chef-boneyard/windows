#
# Author:: Seth Chisamore (<schisamo@chef.io>)
# Cookbook:: windows
# Resource:: feature_dism
#
# Copyright:: 2011-2018, Chef Software, Inc.
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

property :feature_name, [Array, String], coerce: proc { |x| to_formatted_array(x) }, name_property: true
property :source, String
property :all, [true, false], default: false
property :timeout, Integer, default: 600

# @return [Array] lowercase the array unless we're on < Windows 2012
def to_formatted_array(x)
  x = x.split(/\s*,\s*/) if x.is_a?(String) # split multiple forms of a comma separated list

  # feature installs on windows < 2012 are case sensitive so only downcase when on 2012+
  # @todo when we're really ready to remove support for Windows 2008 R2 this check can go away
  older_than_2012_or_8? ? x : x.map(&:downcase)
end

# a simple helper to determine if we're on a windows release pre-2012 / 8
# @return [Boolean] Is the system older than Windows 8 / 2012
def older_than_2012_or_8?
  node['platform_version'].to_f < 6.2
end

include Windows::Helper

action :install do
  reload_cached_dism_data unless node['dism_features_cache']
  fail_if_unavailable # fail if the features don't exist
  fail_if_removed # fail if the features are in removed state

  Chef::Log.debug("Windows features needing installation: #{features_to_install.empty? ? 'none' : features_to_install.join(',')}")
  unless features_to_install.empty?
    message = "install Windows feature#{'s' if features_to_install.count > 1} #{features_to_install.join(',')}"
    converge_by(message) do
      install_command = "#{dism} /online /enable-feature #{features_to_install.map { |f| "/featurename:#{f}" }.join(' ')} /norestart"
      install_command << " /LimitAccess /Source:\"#{new_resource.source}\"" if new_resource.source
      install_command << ' /All' if new_resource.all

      shell_out!(install_command, returns: [0, 42, 127, 3010], timeout: new_resource.timeout)

      reload_cached_dism_data # Reload cached dism feature state
    end
  end
end

action :remove do
  reload_cached_dism_data unless node['dism_features_cache']

  Chef::Log.debug("Windows features needing removal: #{features_to_remove.empty? ? 'none' : features_to_remove.join(',')}")
  unless features_to_remove.empty?
    message = "remove Windows feature#{'s' if features_to_remove.count > 1} #{features_to_remove.join(',')}"

    converge_by(message) do
      shell_out!("#{dism} /online /disable-feature #{features_to_remove.map { |f| "/featurename:#{f}" }.join(' ')} /norestart", returns: [0, 42, 127, 3010], timeout: new_resource.timeout)

      reload_cached_dism_data # Reload cached dism feature state
    end
  end
end

action :delete do
  raise_if_delete_unsupported

  reload_cached_dism_data unless node['dism_features_cache']

  fail_if_unavailable # fail if the features don't exist

  Chef::Log.debug("Windows features needing deletion: #{features_to_delete.empty? ? 'none' : features_to_delete.join(',')}")
  unless features_to_delete.empty?
    message = "delete Windows feature#{'s' if features_to_delete.count > 1} #{features_to_delete.join(',')} from the image"
    converge_by(message) do
      shell_out!("#{dism} /online /disable-feature #{features_to_delete.map { |f| "/featurename:#{f}" }.join(' ')} /Remove /norestart", returns: [0, 42, 127, 3010], timeout: new_resource.timeout)

      reload_cached_dism_data # Reload cached dism feature state
    end
  end
end

action_class do
  # @return [Array] features the user has requested to install which need installation
  def features_to_install
    @install ||= begin
      # disabled features are always available to install
      available_for_install = node['dism_features_cache']['disabled'].dup

      # if the user passes a source then removed features are also available for installation
      available_for_install.concat(node['dism_features_cache']['removed']) if new_resource.source

      # the intersection of the features to install & disabled/removed(if passing source) features are what needs installing
      new_resource.feature_name & available_for_install
    end
  end

  # @return [Array] features the user has requested to remove which need removing
  def features_to_remove
    # the intersection of the features to remove & enabled features are what needs removing
    @remove ||= new_resource.feature_name & node['dism_features_cache']['enabled']
  end

  # @return [Array] features the user has requested to delete which need deleting
  def features_to_delete
    # the intersection of the features to remove & enabled/disabled features are what needs removing
    @remove ||= begin
      all_available = node['dism_features_cache']['enabled'] +
                      node['dism_features_cache']['disabled']
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
    all_available = node['dism_features_cache']['enabled'] +
                    node['dism_features_cache']['disabled'] +
                    node['dism_features_cache']['removed']

    # the difference of desired features to install to all features is what's not available
    unavailable = (new_resource.feature_name - all_available)
    raise "The Windows feature#{'s' if unavailable.count > 1} #{unavailable.join(',')} #{unavailable.count > 1 ? 'are' : 'is'} not available on this version of Windows. Run 'dism /online /Get-Features' to see the list of available feature names." unless unavailable.empty?
  end

  # run dism.exe to get a list of all available features and their state
  # and save that to the node at node.override level.
  # We do this because getting a list of features in dism takes at least a second
  # and this data will be persisted across multiple resource runs which gives us
  # a much faster run when no features actually need to be installed / removed.
  # @return [void]
  def reload_cached_dism_data
    Chef::Log.debug('Caching Windows features available via dism.exe.')
    node.override['dism_features_cache'] = Mash.new
    node.override['dism_features_cache']['enabled'] = []
    node.override['dism_features_cache']['disabled'] = []
    node.override['dism_features_cache']['removed'] = []

    # Grab raw feature information from dism command line
    raw_list_of_features = shell_out("#{dism} /Get-Features /Online /Format:Table /English").stdout

    # Split stdout into an array by windows line ending
    features_list = raw_list_of_features.split("\r\n")
    features_list.each do |feature_details_raw|
      case feature_details_raw
      when /Payload Removed/ # matches 'Disabled with Payload Removed'
        add_to_feature_mash('removed', feature_details_raw)
      when /Enable/ # matches 'Enabled' and 'Enable Pending' aka after reboot
        add_to_feature_mash('enabled', feature_details_raw)
      when /Disable/ # matches 'Disabled' and 'Disable Pending' aka after reboot
        add_to_feature_mash('disabled', feature_details_raw)
      end
    end
    Chef::Log.debug("The dism cache contains\n#{node['dism_features_cache']}")
  end

  # parse the feature string and add the values to the appropriate array
  # in the
  # strips trailing whitespace characters then split on n number of spaces
  # + | +  n number of spaces
  # @return [void]
  def add_to_feature_mash(feature_type, feature_string)
    feature_details = feature_string.strip.split(/\s+[|]\s+/).first

    # dism on windows 2012+ isn't case sensitive so it's best to compare
    # lowercase lists so the user input doesn't need to be case sensitive
    # @todo when we're ready to remove windows 2008R2 the gating here can go away
    feature_details.downcase! unless older_than_2012_or_8?
    node.override['dism_features_cache'][feature_type] << feature_details
  end

  # Fail if any of the packages are in a removed state
  # @return [void]
  def fail_if_removed
    return if new_resource.source # if someone provides a source then all is well
    if node['platform_version'].to_f > 6.2 # 2012R2 or later
      return if registry_key_exists?('HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Servicing') && registry_value_exists?('HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Servicing', name: 'LocalSourcePath') # if source is defined in the registry, still fine
    end
    removed = new_resource.feature_name & node['dism_features_cache']['removed']
    raise "The Windows feature#{'s' if removed.count > 1} #{removed.join(',')} #{removed.count > 1 ? 'are' : 'is'} have been removed from the host and cannot be installed." unless removed.empty?
  end

  # Fail unless we're on windows 8+ / 2012+ where deleting a feature is supported
  # @return [void]
  def raise_if_delete_unsupported
    raise Chef::Exceptions::UnsupportedAction, "#{self} :delete action not support on Windows releases before Windows 8/2012. Cannot continue!" if older_than_2012_or_8?
  end

  # find dism accounting for File System Redirector
  # http://msdn.microsoft.com/en-us/library/aa384187(v=vs.85).aspx
  def dism
    @dism ||= begin
      locate_sysnative_cmd('dism.exe')
    end
  end
end
