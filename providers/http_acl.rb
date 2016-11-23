#
# Author:: Richard Lavey (richard.lavey@calastone.com)
# Cookbook:: windows
# Provider:: http_acl
#
# Copyright:: 2015-2016, Calastone Ltd.
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

# See https://msdn.microsoft.com/en-us/library/windows/desktop/cc307236%28v=vs.85%29.aspx for netsh info

include Chef::Mixin::ShellOut
include Windows::Helper

# Support whyrun
def whyrun_supported?
  true
end

action :create do
  raise '`user` xor `sddl` can\'t be used together' if @new_resource.user && @new_resource.sddl
  raise 'When provided user property can\'t be empty' if @new_resource.user && @new_resource.user.empty?
  raise 'When provided sddl property can\'t be empty' if @new_resource.sddl && @new_resource.sddl.empty?

  if @current_resource.exists
    sddl_changed = (@current_resource.sddl.casecmp(@new_resource.sddl) != 0)
    user_changed = (@current_resource.user.casecmp(@new_resource.user) != 0)

    if sddl_changed || user_changed
      converge_by("Changing #{@current_resource.url}") do
        deleteAcl
        setAcl
      end
    else
      Chef::Log.debug("#{@current_resource.url} already set - nothing to do")
    end
  else
    converge_by("Setting #{@current_resource.url}") do
      setAcl
    end
  end
end

action :delete do
  if @current_resource.exists
    converge_by("Deleting #{@current_resource.url}") do
      deleteAcl
    end
  else
    Chef::Log.debug("#{@current_resource.url} does not exist - nothing to do")
  end
end

def load_current_resource
  @current_resource = Chef::Resource::WindowsHttpAcl.new(@new_resource.name)
  @current_resource.url(@new_resource.url)

  @command = locate_sysnative_cmd('netsh.exe')
  getCurrentAcl
end

private

def getCurrentAcl
  cmd_out = shell_out!("#{@command} http show urlacl url=#{@current_resource.url}").stdout
  Chef::Log.debug "netsh reports: #{cmd_out}"

  if cmd_out.include? @current_resource.url
    @current_resource.exists = true

    # Checks first for sddl, because it generates user(s)
    sddl_match = cmd_out.match(/SDDL:\s*(?<sddl>.+)/)
    if sddl_match
      @current_resource.sddl(sddl_match['sddl'])
    else
      # if no sddl, tries to find a single user
      user_match = cmd_out.match(/User:\s*(?<user>.+)/)
      @current_resource.user user_match['user']
    end
  end
end

def setAcl
  if @current_resource.sddl
    shell_out!("#{@command} http add urlacl url=#{@new_resource.url} sddl=\"#{@new_resource.sddl}\"")
  else
    shell_out!("#{@command} http add urlacl url=#{@new_resource.url} user=\"#{@new_resource.user}\"")
  end
end

def deleteAcl
  shell_out!("#{@command} http delete urlacl url=#{@new_resource.url}")
end
