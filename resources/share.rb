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

  share_cmd = "Get-SmbShare -Name '#{desired.share_name}' | Select-Object Name,Path, Description, Temporary, CATimeout, ContinuouslyAvailable, ConcurrentUserLimit,EncryptData,ThrottleLimit | ConvertTo-Json"

  Chef::Log.debug("Determining share state by running #{share_cmd}")
  ps_results = powershell_out(share_cmd)

  # detect a failure without raising and then set current_resource to nil
  if ps_results.error?
    Chef::Log.debug("Error fetching share state: #{ps_results.stderr}")
    current_value_does_not_exist!
  end

  Chef::Log.debug("The results were #{ps_results.stdout}")
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

  perm_cmd = %(Get-SmbShareAccess -Name "#{desired.share_name}" | Select-Object AccountName,AccessControlType,AccessRight | ConvertTo-Json)

  Chef::Log.debug("Running '#{perm_cmd}' to determine share permissions state'")
  ps_perm_results = powershell_out(perm_cmd)

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

    # powershell for create is different than updates
    if current_resource.nil?
      create_share
    else
      update_share
    end
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
  end

  def delete_share
    powershell_out!("Remove-SmbShare -Name \"#{new_resource.share_name}\" -Description \"#{new_resource.description}\" -Confirm")
  end

  def update_share
    Chef::Log.warn("Updating #{new_resource.share_name}")
    powershell_out!("Set-SmbShare -Name '#{new_resource.share_name}' -Description '#{new_resource.description}' -Confirm")
  end

  def create_share
    Chef::Log.warn("Creating #{new_resource.share_name}")

    raise "#{new_resource.path} is missing or not a directory" unless ::File.directory? new_resource.path

    powershell_out!("New-SmbShare -Name \"#{new_resource.share_name}\" -Path \"#{new_resource.path}\" -Confirm")
  end

  # set_share_permissions - Enforce the share permissions as dictated by the resource attributes
  def set_share_permissions
    share_permissions_script = <<-EOH
      Function New-SecurityDescriptor
      {
        param (
          [array]$ACEs
        )
        #Create SeCDesc object
        $SecDesc = ([WMIClass] "\\\\$env:ComputerName\\root\\cimv2:Win32_SecurityDescriptor").CreateInstance()

        foreach ($ACE in $ACEs )
        {
          $SecDesc.DACL += $ACE.psobject.baseobject
        }

        #Return the security Descriptor
        return $SecDesc
      }

      Function New-ACE
      {
        param  (
          [string] $Name,
          [string] $Domain,
          [string] $Permission = "Read"
        )
        #Create the Trusteee Object
        $Trustee = ([WMIClass] "\\\\$env:computername\\root\\cimv2:Win32_Trustee").CreateInstance()
        $account = get-wmiobject Win32_Account -filter "Name = '$Name' and Domain = '$Domain'"
        $accountSID = [WMI] "\\\\$env:ComputerName\\root\\cimv2:Win32_SID.SID='$($account.sid)'"

        $Trustee.Domain = $Domain
        $Trustee.Name = $Name
        $Trustee.SID = $accountSID.BinaryRepresentation

        #Create ACE (Access Control List) object.
        $ACE = ([WMIClass] "\\\\$env:ComputerName\\root\\cimv2:Win32_ACE").CreateInstance()
        switch ($Permission)
        {
          "Read" 		 { $ACE.AccessMask = 1179817 }
          "Change"  {	$ACE.AccessMask = 1245631 }
          "Full"		   { $ACE.AccessMask = 2032127 }
          default { throw "$Permission is not a supported permission value. Possible values are 'Read','Change','Full'" }
        }

        $ACE.AceFlags = 3
        $ACE.AceType = 0
        $ACE.Trustee = $Trustee

        $ACE
      }

      $dacl_array = @()

    EOH
    new_resource.full_users.each do |user|
      share_permissions_script += user_to_ace(user, 'Full')
    end

    new_resource.change_users.each do |user|
      share_permissions_script += user_to_ace(user, 'Change')
    end

    new_resource.read_users.each do |user|
      share_permissions_script += user_to_ace(user, 'Read')
    end

    share_permissions_script += <<-EOH

      $dacl = New-SecurityDescriptor -Aces $dacl_array

      $share = get-wmiobject win32_share -filter 'Name like "#{new_resource.share_name}"'
      $return = $share.SetShareInfo($null, '#{new_resource.description}', $dacl)
      exit $return.returnValue
    EOH
    r = powershell_out(share_permissions_script)
    raise "Could not set share permissions.  Win32_Share.SedtShareInfo returned #{r.exitstatus}" if r.error?
  end

  def user_to_ace(fully_qualified_user_name, access)
    domain, user = fully_qualified_user_name.split('\\')
    unless domain && user
      raise "Invalid user entry #{fully_qualified_user_name}.  The user names must be specified as 'DOMAIN\\user'"
    end
    "\n$dacl_array += new-ace -Name '#{user}' -domain '#{domain}' -permission '#{access}'"
  end
end
