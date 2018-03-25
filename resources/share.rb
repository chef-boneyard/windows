
# -*- coding: utf-8 -*-
#
# Author:: Sölvi Páll Ásgeirsson (<solvip@gmail.com>), Richard Lavey (richard.lavey@calastone.com)
# Cookbook:: windows
# Resource:: share
#
# Copyright:: 2014-2017, Sölvi Páll Ásgeirsson.
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
property :full_users, Array, default: []

# Specifies which users are granted modify permission to access the share
property :change_users, Array, default: []

# Specifies which users are granted read permission to access the share. Multiple users can be specified by supplying a comma-separated list.
property :read_users, Array, default: []

# Specifies the lifetime of the new SMB share. A temporary share does not persist beyond the next restart of the computer. By default, new SMB shares are persistent, and non-temporary.
property :temporary, [true, false], default: false

# Specifies the security descriptor for the SMB share in string format.
property :security_descriptor, String

# Specifies the scope name of the share.
property :scope_name, String, default: '*'

# Specifies the continuous availability time-out for the share.
property :ca_timeout, Integer, default: 0

# Indicates that the share is continuously available.
property :continuously_available, [true, false], default: false

# Specifies the caching mode of the offline files for the SMB share.
property :caching_mode, String, equal_to: %w(None Manual Documents Programs BranchCache)

# Specifies the maximum number of concurrently connected users that the new SMB share may accommodate. If this parameter is set to zero (0), then the number of users is unlimited.
property :concurrent_user_limit, Integer, default: 0

# Indicates that the share is encrypted.
property :encrypt_data, [true, false], default: false

# Specifies which files and folders in the SMB share are visible to users. AccessBased: SMB does not the display the files and folders for a share to a user unless that user has rights to access the files and folders. By default, access-based enumeration is disabled for new SMB shares. Unrestricted: SMB displays files and folders to a user even when the user does not have permission to access the items.
property :folder_enumeration_mode, String, equal_to: %(AccessBased Unrestricted)

property :throttle_limit, Integer, default: 0

include Windows::Helper
include Chef::Mixin::PowershellOut

load_current_value do |desired|
  # this command selects individual objects because EncryptData & CachingMode have underlying
  # types that get converted to their Integer values by ConvertTo-Json & we need to make sure
  # those get written out as strings
  share_cmd = %(Get-SmbShare -Name '#{desired.share_name}' | Select-Object Name,Path, Description, Temporary, SecurityDescriptor, ScopeName, CATimeout, ContinuouslyAvailable, @{Name='CachingMode';Expression={"$($_.CachingMode)"}},ConcurrentUserLimit,EncryptData, @{Name='FolderEnumerationMode';Expression={"$($_.FolderEnumerationMode)"}},ThrottleLimit | ConvertTo-Json)

  Chef::Log.debug("Running #{share_cmd}")
  ps_results = powershell_out(share_cmd)
  puts ps_results.stdout
  current_value_does_not_exist! if ps_results.error?

  results = Chef::JSONCompat.from_json(ps_results.stdout)
  path results['Path']
  description results['Description']
  temporary results['Temporary']
  security_descriptor results['SecurityDescriptor']
  scope_name results['ScopeName']
  ca_timeout results['CATimeout']
  continuously_available results['ContinuouslyAvailable']
  caching_mode results['CachingMode']
  concurrent_user_limit results['ConcurrentUserLimit']
  encrypt_data results['EncryptData']
  folder_enumeration_mode results['FolderEnumerationMode']
  throttle_limit results['ThrottleLimit']

  perm_cmd = %(Get-SmbShareAccess -Name "#{desired.share_name}" | Select-Object AccountName,AccessControlType,AccessRight | ConvertTo-Json)

  Chef::Log.debug("Running '#{perm_cmd}' to determine share permissions state'")
  ps_results = powershell_out(perm_cmd)

  raise "Could not determine #{desired.share_name} share permissions by running '#{perm_cmd}'" if ps_results.error?
  results = Chef::JSONCompat.from_json(ps_results.stdout)

  f_users = []
  c_users = []
  r_users = []

  results.each do |perm|
    next unless perm['AccessControlType'] == 0 # allow
    case perm['AccessRight']
    when 0 then f_users << perm['AccountName'] # 0 full control
    when 1 then c_users << perm['AccountName'] # 1 == change
    when 2 then r_users << perm['AccountName'] # 2 == read
    end
  end

  full_users f_users
  change_users c_users
  read_users r_users
end

action :create do
  raise 'No path property set' unless new_resource.path

  if different_path?
    unless current_resource.nil?
      converge_by("remove previous share #{new_resource.share_name}") do
        delete_share
      end
    end
    converge_by("create share #{new_resource.share_name}") do
      create_share
    end
  end

  if different_members?(:full_users) ||
     different_members?(:change_users) ||
     different_members?(:read_users) ||
     different_description?
    converge_by("Setting permissions and description for #{new_resource.share_name}") do
      set_share_permissions
    end
  end
end

action :delete do
  if !current_resource.nil?
    converge_by("delete #{new_resource.share_name}") do
      delete_share
    end
  else
    Chef::Log.debug("#{new_resource.share_name} does not exist - nothing to do")
  end
end

action_class do
  def description_exists?(resource)
    !resource.description.nil?
  end

  def different_description?
    if description_exists?(new_resource) && description_exists?(current_resource)
      new_resource.description.casecmp(current_resource.description) != 0
    else
      description_exists?(new_resource) || description_exists?(current_resource)
    end
  end

  def different_path?
    return true if current_resource.nil?
    win_friendly_path(new_resource.path).casecmp(win_friendly_path(current_resource.path)) != 0
  end

  def different_members?(permission_type)
    !(current_resource.send(permission_type.to_sym) - new_resource.send(permission_type.to_sym).map(&:downcase)).empty? ||
      !(new_resource.send(permission_type.to_sym).map(&:downcase) - current_resource.send(permission_type.to_sym)).empty?
  end

  def delete_share
    powershell_out("Remove-SmbShare -Name \"#{new_resource.share_name}\" -Description \"#{new_resource.description}\" -Confirm")
  end

  def create_share
    raise "#{new_resource.path} is missing or not a directory" unless ::File.directory? new_resource.path

    powershell_out("New-SmbShare -Name \"#{new_resource.share_name}\" -Path \"#{new_resource.path}\" -Confirm")
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
