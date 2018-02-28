#
# Author:: Seth Chisamore (<schisamo@chef.io>)
# Cookbook:: windows
# Provider:: feature_dism
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

property :feature_name, [Array, String], coerce: proc { |x| to_array(x) }, name_property: true
property :source, String
property :all, [true, false], default: false
property :timeout, Integer, default: 600

include Windows::Helper

action :install do
  Chef::Log.warn("Requested feature #{new_resource.feature_name.join(',')} is not available on this system.") unless available?
  unless !available? || installed?
    converge_by("install Windows feature #{new_resource.feature_name.join(',')}") do
      addsource = new_resource.source ? "/LimitAccess /Source:\"#{new_resource.source}\"" : ''
      addall = new_resource.all ? '/All' : ''
      shell_out!("#{dism} /online /enable-feature #{to_array(new_resource.feature_name).map { |feature| "/featurename:#{feature}" }.join(' ')} /norestart #{addsource} #{addall}", returns: [0, 42, 127, 3010], timeout: new_resource.timeout)
      reload_cached_dism_data # Reload cached dism feature state
    end
  end
end

action :remove do
  if installed?
    converge_by("remove Windows feature #{new_resource.feature_name.join(',')}") do
      shell_out!("#{dism} /online /disable-feature #{to_array(new_resource.feature_name).map { |feature| "/featurename:#{feature}" }.join(' ')} /norestart", returns: [0, 42, 127, 3010], timeout: new_resource.timeout)
      reload_cached_dism_data # Reload cached dism feature state
    end
  end
end

action :delete do
  raise Chef::Exceptions::UnsupportedAction, "#{self} :delete action not support on #{win_version.sku}" unless supports_feature_delete?
  if available?
    converge_by("delete Windows feature #{new_resource.feature_name} from the image") do
      shell_out!("#{dism} /online /disable-feature #{to_array(new_resource.feature_name).map { |feature| "/featurename:#{feature}" }.join(' ')} /Remove /norestart", returns: [0, 42, 127, 3010], timeout: new_resource.timeout)
      reload_cached_dism_data # Reload cached dism feature state
    end
  end
end

action_class do
  def installed?
    @installed ||= begin
      reload_cached_dism_data unless node['dism_features_cache']

      # Compare against cached feature data instead of costly dism run
      node['dism_features_cache'].key?(new_resource.feature_name) && node['dism_features_cache'][new_resource.feature_name] =~ /Enable/
    end
  end

  def available?
    @available ||= begin
      reload_cached_dism_data unless node['dism_features_cache']

      # Compare against cached feature data instead of costly dism run
      node['dism_features_cache'].key?(new_resource.feature_name) && node['dism_features_cache'][new_resource.feature_name] !~ /with payload removed/
    end
  end

  def reload_cached_dism_data
    Chef::Log.debug('Caching Windows features available via dism.exe.')
    node.normal['dism_features_cache'] = Mash.new

    # Grab raw feature information from dism command line
    raw_list_of_features = shell_out("#{dism} /Get-Features /Online /Format:Table /English").stdout

    # Split stdout into an array by windows line ending
    features_list = raw_list_of_features.split("\r\n")
    features_list.each do |feature_details_raw|
      # Skip lines that do not match Enable / Disable
      next unless feature_details_raw =~ /(En|Dis)able/
      # Strip trailing whitespace characters then split on n number of spaces + | +  n number of spaces
      feature_details = feature_details_raw.strip.split(/\s+[|]\s+/)
      # Add to Mash
      node.normal['dism_features_cache'][feature_details.first] = feature_details.last
    end
  end

  def supports_feature_delete?
    win_version.major_version >= 6 && win_version.minor_version >= 2
  end

  # account for File System Redirector
  # http://msdn.microsoft.com/en-us/library/aa384187(v=vs.85).aspx
  def dism
    @dism ||= begin
      locate_sysnative_cmd('dism.exe')
    end
  end
end
