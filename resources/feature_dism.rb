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

property :feature_name, [Array, String], coerce: proc { |x| to_lowercase_array(x) }, name_property: true
property :source, String
property :all, [true, false], default: false
property :timeout, Integer, default: 600

# @return [Array] lowercase the array unless we're on < Windows 2012
def to_lowercase_array(x)
  x = x.split(/\s*,\s*/) if x.is_a?(String) # split multiple forms of a comma separated list

  # dism on windows < 2012 is case sensitive so only downcase when on 2012+
  # @todo when we're really ready to remove support for Windows 2008 R2 this check can go away
  node['platform_version'].to_f < 6.2 ? x : x.map(&:downcase)
end

include Windows::Helper

action :install do
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

      reset_dism_cache # Reload cached dism feature state
    end
  end
end

action :remove do
  Chef::Log.debug("Windows features needing removal: #{features_to_remove.empty? ? 'none' : features_to_remove.join(',')}")
  unless features_to_remove.empty?
    message = "remove Windows feature#{'s' if features_to_remove.count > 1} #{features_to_remove.join(',')}"

    converge_by(message) do
      shell_out!("#{dism} /online /disable-feature #{features_to_remove.map { |f| "/featurename:#{f}" }.join(' ')} /norestart", returns: [0, 42, 127, 3010], timeout: new_resource.timeout)

      reset_dism_cache # Reload cached dism feature state
    end
  end
end

action :delete do
  raise_if_delete_unsupported

  fail_if_unavailable # fail if the features don't exist

  Chef::Log.debug("Windows features needing deletion: #{features_to_delete.empty? ? 'none' : features_to_delete.join(',')}")
  unless features_to_delete.empty?
    message = "delete Windows feature#{'s' if features_to_delete.count > 1} #{features_to_delete.join(',')} from the image"
    converge_by(message) do
      shell_out!("#{dism} /online /disable-feature #{features_to_delete.map { |f| "/featurename:#{f}" }.join(' ')} /Remove /norestart", returns: [0, 42, 127, 3010], timeout: new_resource.timeout)

      reset_dism_cache # Reload cached dism feature state
    end
  end
end

action_class do
  # @return [Array] features the user has requested to install which need installation
  def features_to_install
    @install ||= begin
      # disabled features are always available to install
      available_for_install = dism_cache['disabled']

      # if the user passes a source then removed features are also available for installation
      available_for_install.concat(dism_cache['removed']) if new_resource.source

      # the intersection of the features to install & disabled/removed(if passing source) features are what needs installing
      new_resource.feature_name & available_for_install
    end
  end

  # @return [Array] features the user has requested to remove which need removing
  def features_to_remove
    # the intersection of the features to remove & enabled features are what needs removing
    @remove ||= new_resource.feature_name & dism_cache['enabled']
  end

  # @return [Array] features the user has requested to delete which need deleting
  def features_to_delete
    # the intersection of the features to remove & enabled/disabled features are what needs removing
    @remove ||= begin
      all_available = dism_cache['enabled'] +
                      dism_cache['disabled']
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
    all_available = dism_cache['enabled'] +
                    dism_cache['disabled'] +
                    dism_cache['removed']

    # the difference of desired features to install to all features is what's not available
    unavailable = (new_resource.feature_name - all_available)
    raise "The Windows feature#{'s' if unavailable.count > 1} #{unavailable.join(',')} #{unavailable.count > 1 ? 'are' : 'is'} not available on this version of Windows. Run 'dism /online /Get-Features' to see the list of available feature names." unless unavailable.empty?
  end

  # Fail if any of the packages are in a removed state
  # @return [void]
  def fail_if_removed
    return if new_resource.source # if someone provides a source then all is well
    if node['platform_version'].to_f > 6.2
      return if registry_key_exists?('HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Servicing') && registry_value_exists?('HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Servicing', name: 'LocalSourcePath') # if source is defined in the registry, still fine
    end
    removed = new_resource.feature_name & dism_cache['removed']
    raise "The Windows feature#{'s' if removed.count > 1} #{removed.join(',')} #{removed.count > 1 ? 'are' : 'is'} have been removed from the host and cannot be installed." unless removed.empty?
  end

  # Fail unless we're on windows 8+ / 2012+ where deleting a feature is supported
  # @return [void]
  def raise_if_delete_unsupported
    raise Chef::Exceptions::UnsupportedAction, "#{self} :delete action not support on Windows releases before Windows 8/2012. Cannot continue!" unless node['platform_version'].to_f >= 6.2
  end

  # read the cached dism data
  # @return [Hash] Hash of arrays
  def dism_cache
    DismCache.instance.data
  end

  # reset the cached dism data
  # @return [void]
  def reset_dism_cache
    DismCache.instance.reset
  end

  # find dism accounting for File System Redirector
  # http://msdn.microsoft.com/en-us/library/aa384187(v=vs.85).aspx
  # @return [String] full path to dism.exe
  def dism
    @dism ||= begin
      locate_sysnative_cmd('dism.exe')
    end
  end
end
