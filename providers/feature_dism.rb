#
# Author:: Seth Chisamore (<schisamo@chef.io>)
# Cookbook:: windows
# Provider:: feature_dism
#
# Copyright:: 2011-2016, Chef Software, Inc.
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

use_inline_resources

include Chef::Provider::WindowsFeature::Base
include Chef::Mixin::ShellOut
include Windows::Helper

def install_feature(_name)
  addsource = @new_resource.source ? "/LimitAccess /Source:\"#{@new_resource.source}\"" : ''
  addall = @new_resource.all ? '/All' : ''
  shell_out!("#{dism} /online /enable-feature /featurename:#{@new_resource.feature_name} /norestart #{addsource} #{addall}", returns: [0, 42, 127, 3010])
  # Reload ohai data
  reload_ohai_features_plugin(@new_resource.action, @new_resource.feature_name)
end

def remove_feature(_name)
  shell_out!("#{dism} /online /disable-feature /featurename:#{@new_resource.feature_name} /norestart", returns: [0, 42, 127, 3010])
  # Reload ohai data
  reload_ohai_features_plugin(@new_resource.action, @new_resource.feature_name)
end

def delete_feature(_name)
  if win_version.major_version >= 6 && win_version.minor_version >= 2
    shell_out!("#{dism} /online /disable-feature /featurename:#{@new_resource.feature_name} /Remove /norestart", returns: [0, 42, 127, 3010])
    # Reload ohai data
    reload_ohai_features_plugin(@new_resource.action, @new_resource.feature_name)
  else
    raise Chef::Exceptions::UnsupportedAction, "#{self} :delete action not support on #{win_version.sku}"
  end
end

def installed?
  @installed ||= begin
    install_ohai_plugin unless node['dism_features']

    # Compare against ohai plugin instead of costly dism run
    node['dism_features'].key?(@new_resource.feature_name) && node['dism_features'][@new_resource.feature_name] =~ /Enable/
  end
end

def available?
  @available ||= begin
    install_ohai_plugin unless node['dism_features']

    # Compare against ohai plugin instead of costly dism run
    node['dism_features'].key?(@new_resource.feature_name) && node['dism_features'][@new_resource.feature_name] !~ /with payload removed/
  end
end

def reload_ohai_features_plugin(take_action, feature_name)
  ohai "Reloading Dism_Features Plugin - Action #{take_action} of feature #{feature_name}" do
    action :reload
    plugin 'dism_features'
  end
end

def install_ohai_plugin
  Chef::Log.info("node['dism_features'] data missing. Installing the dism_features Ohai plugin")

  ohai_plugin 'dism_features' do
    compile_time true
    cookbook 'windows'
  end
end

private

# account for File System Redirector
# http://msdn.microsoft.com/en-us/library/aa384187(v=vs.85).aspx
def dism
  @dism ||= begin
    locate_sysnative_cmd('dism.exe')
  end
end
