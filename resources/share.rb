#
# Author:: Sölvi Páll Ásgeirsson (<solvip@gmail.com>)
# Author:: Richard Lavey (richard.lavey@calastone.com)
# Author:: Tim Smith (tsmith@chef.io)
# Cookbook:: windows
# Resource:: share
#
# Copyright:: 2014-2017, Sölvi Páll Ásgeirsson.
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

require 'win32ole' if RUBY_PLATFORM =~ /mswin|mingw32|windows/
require 'chef/json_compat'

# Specifies a name for the SMB share. The name may be composed of any valid file name characters, but must be less than 80 characters long. The names pipe and mailslot are reserved for use by the computer.
property :share_name, String, name_property: true

# Specifies the path of the location of the folder to share. The path must be fully qualified. Relative paths or paths that contain wildcard characters are not permitted.
property :path, String

# Specifies an optional description of the SMB share. A description of the share is displayed by running the Get-SmbShare cmdlet. The description may not contain more than 256 characters.
property :description, String, default: ''

# Specifies which accounts are granted full permission to access the share. Use a comma-separated list to specify multiple accounts. An account may not be specified more than once in the FullAccess, ChangeAccess, or ReadAccess parameter lists, but may be specified once in the FullAccess, ChangeAccess, or ReadAccess parameter list and once in the NoAccess parameter list.
property :full_users, Array, default: [], coerce: proc { |u| u.sort }

# Specifies which users are granted modify permission to access the share
property :change_users, Array, default: [], coerce: proc { |u| u.sort }

# Specifies which users are granted read permission to access the share. Multiple users can be specified by supplying a comma-separated list.
property :read_users, Array, default: [], coerce: proc { |u| u.sort }

# Specifies the lifetime of the new SMB share. A temporary share does not persist beyond the next restart of the computer. By default, new SMB shares are persistent, and non-temporary.
property :temporary, [true, false], default: false

# Specifies the scope name of the share.
property :scope_name, String, default: '*'

# Specifies the continuous availability time-out for the share.
property :ca_timeout, Integer, default: 0

# Indicates that the share is continuously available.
property :continuously_available, [true, false], default: false

# Specifies the caching mode of the offline files for the SMB share.
# property :caching_mode, String, equal_to: %w(None Manual Documents Programs BranchCache)

# Specifies the maximum number of concurrently connected users that the new SMB share may accommodate. If this parameter is set to zero (0), then the number of users is unlimited.
property :concurrent_user_limit, Integer, default: 0

# Indicates that the share is encrypted.
property :encrypt_data, [true, false], default: false

# Specifies which files and folders in the SMB share are visible to users. AccessBased: SMB does not the display the files and folders for a share to a user unless that user has rights to access the files and folders. By default, access-based enumeration is disabled for new SMB shares. Unrestricted: SMB displays files and folders to a user even when the user does not have permission to access the items.
# property :folder_enumeration_mode, String, equal_to: %(AccessBased Unrestricted)

property :throttle_limit, [Integer, nil]

include Chef::Mixin::PowershellOut

load_current_value do |desired|
  # this command selects individual objects because EncryptData & CachingMode have underlying
  # types that get converted to their Integer values by ConvertTo-Json & we need to make sure
  # those get written out as strings
  share_state_cmd = "Get-SmbShare -Name '#{desired.share_name}' | Select-Object Name,Path, Description, Temporary, CATimeout, ContinuouslyAvailable, ConcurrentUserLimit, EncryptData, ThrottleLimit | ConvertTo-Json"

  Chef::Log.debug("Determining share state by running #{share_state_cmd}")
  ps_results = powershell_out(share_state_cmd)

  # detect a failure without raising and then set current_resource to nil
  if ps_results.error?
    Chef::Log.debug("Error fetching share state: #{ps_results.stderr}")
    current_value_does_not_exist!
  end

  Chef::Log.debug("The Get-SmbShare results were #{ps_results.stdout}")
  results = Chef::JSONCompat.from_json(ps_results.stdout)

  path results['Path']
  description results['Description']
  temporary results['Temporary']
  ca_timeout results['CATimeout']
  continuously_available results['ContinuouslyAvailable']
  # caching_mode results['CachingMode']
  concurrent_user_limit results['ConcurrentUserLimit']
  encrypt_data results['EncryptData']
  # folder_enumeration_mode results['FolderEnumerationMode']
  throttle_limit results['ThrottleLimit']

  perm_state_cmd = %(Get-SmbShareAccess -Name "#{desired.share_name}" | Select-Object AccountName,AccessControlType,AccessRight | ConvertTo-Json)

  Chef::Log.debug("Running '#{perm_state_cmd}' to determine share permissions state'")
  ps_perm_results = powershell_out(perm_state_cmd)

  # we raise here instead of warning like above because we'd only get here if the above Get-SmbShare
  # command was successful and that continuing would leave us with 1/2 known state
  raise "Could not determine #{desired.share_name} share permissions by running '#{perm_cmd}'" if ps_perm_results.error?

  f_users, c_users, r_users = parse_permissions(ps_perm_results.stdout)

  full_users f_users
  change_users c_users
  read_users r_users
end

# given the string output of Get-SmbShareAccess parse out
# arrays of full access users, change users, and read only users
def parse_permissions(results_string)
  json_results = Chef::JSONCompat.from_json(results_string)
  json_results = [json_results] unless json_results.is_a?(Array) # single result is not an array

  f_users = []
  c_users = []
  r_users = []

  json_results.each do |perm|
    next unless perm['AccessControlType'] == 0 # allow
    case perm['AccessRight']
    when 0 then f_users << stripped_account(perm['AccountName']) # 0 full control
    when 1 then c_users << stripped_account(perm['AccountName']) # 1 == change
    when 2 then r_users << stripped_account(perm['AccountName']) # 2 == read
    end
  end
  [f_users, c_users, r_users]
end

# local names are returned from Get-SmbShareAccess in the full format MACHINE\\NAME
# but users of this resource would simply say NAME so we need to strip the values for comparison
def stripped_account(name)
  name.slice!("#{node['hostname']}\\")
  name
end

action :create do
  raise 'No path property set' unless new_resource.path

  converge_if_changed do
    # you can't actually change the path so you have to delete the old share first
    delete_share if different_path?

    # powershell cmdlet for create is different than updates
    if current_resource.nil?
      create_share
    else
      update_share
    end

    update_permissions
  end
end

action :delete do
  if current_resource.nil?
    Chef::Log.debug("#{new_resource.share_name} does not exist - nothing to do")
  else
    converge_by("delete #{new_resource.share_name}") do
      delete_share
    end
  end
end

action_class do
  def different_path?
    return false if current_resource.nil? # going from nil to something isn't different for our concerns
    return false if current_resource.path == new_resource.path
    true
  end

  def delete_share
    Chef::Log.warn("Running 'Remove-SmbShare -Name #{new_resource.share_name} -Force' to remove the share")
    powershell_out!("Remove-SmbShare -Name #{new_resource.share_name} -Force")
  end

  def update_share
    Chef::Log.warn("Updating #{new_resource.share_name}")

    update_command = "Set-SmbShare -Name #{new_resource.share_name} -Description '#{new_resource.description}' -Force"

    Chef::Log.warn("Running '#{update_command}' to update the share")
    powershell_out!(update_command)
  end

  def create_share
    Chef::Log.warn("Creating #{new_resource.share_name}")

    raise "#{new_resource.path} is missing or not a directory. Shares cannot be created if the path doesn't first exist." unless ::File.directory? new_resource.path

    share_cmd = "New-SmbShare -Name #{new_resource.share_name} -Path #{new_resource.path} -Description '#{new_resource.description}' -ConcurrentUserLimit #{new_resource.concurrent_user_limit} -CATimeout #{new_resource.ca_timeout} -EncryptData:#{bool_string(new_resource.encrypt_data)} -ContinuouslyAvailable:#{bool_string(new_resource.continuously_available)}"
    share_cmd << "-ThrottleLimit #{new_resource.throttle_limit}" if new_resource.throttle_limit # defaults to nil so we need to check before passing nil
    share_cmd << " -ScopeName #{new_resource.scope_name}" unless new_resource.scope_name == '*' # passing * causes the command to fail
    share_cmd << " -Temporary:#{bool_string(new_resource.temporary)}" if new_resource.temporary # only set true

    Chef::Log.warn("Running '#{share_cmd}' to create the share")
    powershell_out!(share_cmd)
  end

  # determine what users in the current state don't exist in the desired state
  # users/groups will have their permissions updated with the same command that
  # sets it, but removes must be performed with Revoke-SmbShareAccess
  def users_to_revoke
    @users_to_revoke ||= begin
      # if the resource doesn't exist then nothing needs to be revoked
      if current_resource.nil?
        []
      else # if it exists then calculate the current to new resource diffs
        (current_resource.full_users + current_resource.change_users + current_resource.read_users) - (new_resource.full_users + new_resource.change_users + new_resource.read_users)
      end
    end
  end

  def update_permissions
    # revoke any users that had something, but now have absolutely nothing
    revoke_user_permissions(users_to_revoke) unless users_to_revoke.empty?

    %w(Full Read Change).each do |perm_type|
      property_name = "#{perm_type.downcase}_users"

      # update permissions for a brand new share OR
      # update permissions if the current state and desired state differs
      if current_resource.nil? || !(current_resource.send(property_name) - new_resource.send(property_name)).empty?
        Chef::Log.warn("would set user permission type #{perm_type}")
      end
    end
  end

  def revoke_user_permissions(users)
    Chef::Log.warn("would revoke #{users}")
  end

  # convert True/False into "$True" & "$False"
  def bool_string(bool)
    # bool ? 1 : 0
    bool ? '$true' : '$false'
  end
end
