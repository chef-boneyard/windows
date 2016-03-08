#
# Author:: Seth Chisamore (<schisamo@chef.io>)
# Cookbook Name:: windows
# Provider:: feature_dism
#
# Copyright:: 2011-2015, Chef Software, Inc.
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
use_inline_resources if defined?(use_inline_resources)

include Chef::Provider::WindowsFeature::Base
include Chef::Mixin::ShellOut
include Windows::Helper

def install_feature(_name)
  addsource = @new_resource.source ? "/LimitAccess /Source:\"#{@new_resource.source}\"" : ''
  addall = @new_resource.all ? '/All' : ''
  shell_out!("#{dism} /online /enable-feature /featurename:#{@new_resource.feature_name} /norestart #{addsource} #{addall}", returns: [0, 42, 127, 3010])
  clear_cache
end

def remove_feature(_name)
  shell_out!("#{dism} /online /disable-feature /featurename:#{@new_resource.feature_name} /norestart", returns: [0, 42, 127, 3010])
  clear_cache
end

def delete_feature(_name)
  if win_version.major_version >= 6 && win_version.minor_version >= 2
    shell_out!("#{dism} /online /disable-feature /featurename:#{@new_resource.feature_name} /Remove /norestart", returns: [0, 42, 127, 3010])
  else
    raise Chef::Exceptions::UnsupportedAction, "#{self} :delete action not support on #{win_version.sku}"
  end
  clear_cache
end

def installed?
  @installed ||= begin
    feature_list = get_feature_list
    feature_list.stderr.empty? && (feature_list.stdout =~ /^Feature Name : #{@new_resource.feature_name}.?$\n^State : Enabled.?$/i)
  end
end

def available?
  @available ||= begin
    feature_list = get_feature_list
    feature_list.stderr.empty? && (feature_list.stdout !~ /^Feature Name : #{@new_resource.feature_name}.?$\n^State : .* with payload removed.?$/i)
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

@@feature_list = nil
def get_feature_list
  if @@feature_list.nil?
    @@feature_list = shell_out("#{dism} /online /Get-Features", returns: [0, 42, 127])
  end
end

def clear_cache
  @@feature_list = nil
end
