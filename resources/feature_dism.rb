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

property :feature_name, [Array, String], coerce: proc { |x| to_array(x) }, name_property: true
property :source, String
property :all, [true, false], default: false
property :timeout, Integer, default: 600

include Windows::Helper

action :install do
  # fail if we can't install the specified feature(s)
  fail_if_unavailable

  unless features_needing_install.empty?
    converge_by("install Windows feature#{'s' if features_needing_install.count > 1} #{features_needing_install.join(',')}") do
      addsource = new_resource.source ? "/LimitAccess /Source:\"#{new_resource.source}\"" : ''
      addall = new_resource.all ? '/All' : ''
      shell_out!("#{dism} /online /enable-feature #{features_needing_install.map { |feature| "/featurename:#{feature}" }.join(' ')} /norestart #{addsource} #{addall}", returns: [0, 42, 127, 3010], timeout: new_resource.timeout)
      reload_cached_dism_data # Reload cached dism feature state
    end
  end
end

action :remove do
  unless features_needing_uninstall.empty?
    converge_by("remove Windows feature#{'s' if features_needing_install.count > 1} #{new_resource.feature_name.join(',')}") do
      shell_out!("#{dism} /online /disable-feature #{new_resource.feature_name.map { |feature| "/featurename:#{feature}" }.join(' ')} /norestart", returns: [0, 42, 127, 3010], timeout: new_resource.timeout)
      reload_cached_dism_data # Reload cached dism feature state
    end
  end
end

action :delete do
  raise Chef::Exceptions::UnsupportedAction, "#{self} :delete action not support on Windows releases before Windows 8/2012. Cannot continue!" unless supports_feature_delete?
  if available?
    converge_by("delete Windows feature#{'s' if features_needing_install.count > 1} #{new_resource.feature_name} from the image") do
      shell_out!("#{dism} /online /disable-feature #{new_resource.feature_name.map { |feature| "/featurename:#{feature}" }.join(' ')} /Remove /norestart", returns: [0, 42, 127, 3010], timeout: new_resource.timeout)
      reload_cached_dism_data # Reload cached dism feature state
    end
  end
end

action_class do
  def features_needing_uninstall
    @to_uninstall ||= begin
      reload_cached_dism_data unless node['dism_features_cache']

      to_uninstall = []
      new_resource.feature_name.each do |f|
        to_uninstall << f if node['dism_features_cache'][new_resource.feature_name] =~ /Enable/
      end
      to_uninstall
    end
  end

  def features_needing_install
    @to_install ||= begin
      reload_cached_dism_data unless node['dism_features_cache']

      to_install = []
      new_resource.feature_name.each do |f|
        to_install << f unless node['dism_features_cache'][new_resource.feature_name] =~ /Enable/
      end
      to_install
    end
  end

  # if any features are not supported on this release of Windows or
  # have been deleted raise with a friendly message. At one point in time
  # we just warned, but this goes against the behavior of ever other package
  # provider in Chef and it isn't clear what you'd want if you passed an array
  # and some features were available and others were not.
  # @return [void]
  def fail_if_unavailable
    reload_cached_dism_data unless node['dism_features_cache']

    new_resource.feature_name.each do |f|
      raise "The Windows feature #{f} is not available on this release of Windows. Run 'dism /online /Get-Features' to see the list of available feature names." unless node['dism_features_cache'].key?(f)
      raise "The Windows feature #{f} cannot be installed as it has been removed from the system. Cannot continue!" if node['dism_features_cache'][f] !~ /with payload removed/
    end
  end

  # run dism.exe to get a list of all available features and their state
  # and save that to the node at node.normal (same as ohai) level.
  # We do this because getting a list of features in dism takes at least a second
  # and this data will be persisted across multiple resource runs which gives us
  # a much faster run when no features actually need to be installed / removed.
  # @return [void]
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

  # Are we on windows 8+ / 2012+ where deleting a feature is supported
  # @return [boolean]
  def supports_feature_delete?
    node['platform_version'].to_f >= 6.2
  end

  # find dism accounting for File System Redirector
  # http://msdn.microsoft.com/en-us/library/aa384187(v=vs.85).aspx
  def dism
    @dism ||= begin
      locate_sysnative_cmd('dism.exe')
    end
  end
end
