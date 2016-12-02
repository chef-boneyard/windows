# -*- coding: utf-8 -*-
#
# Author:: Sölvi Páll Ásgeirsson (<solvip@gmail.com>), Richard Lavey (richard.lavey@calastone.com)
# Cookbook Name:: windows
# Provider:: share
#
# Copyright:: 2014, Sölvi Páll Ásgeirsson
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
include Windows::Helper

require 'win32ole' if RUBY_PLATFORM =~ /mswin|mingw32|windows/

use_inline_resources

ACCESS_FULL = 2_032_127
ACCESS_CHANGE = 1_245_631
ACCESS_READ = 1_179_817

# Support whyrun
def whyrun_supported?
  true
end

action :delete do
  if @current_resource.exists
    converge_by("Deleting #{@current_resource.share_name}") do
      delete_share
    end
  else
    Chef::Log.debug("#{@current_resource.share_name} does not exist - nothing to do")
  end
end

action :create do
  raise 'No path property set' unless @new_resource.path

  if @current_resource.exists
    recreateRequired = (@current_resource.path.casecmp(win_friendly_path(@new_resource.path)) != 0)

    # note that we downcase the new user arrays so they match the lower case current values
    needsChange = recreateRequired ||
                  (@current_resource.description != @new_resource.description)
    (@current_resource.full_users.count != @new_resource.full_users.count) ||
      (@current_resource.change_users.count != @new_resource.change_users.count) ||
      (@current_resource.read_users.count != @new_resource.read_users.count) ||
      !(@current_resource.full_users - @new_resource.full_users.map(&:downcase)).empty? ||
      !(@current_resource.change_users - @new_resource.change_users.map(&:downcase)).empty? ||
      !(@current_resource.read_users - @new_resource.read_users.map(&:downcase)).empty?

    if needsChange
      converge_by("Changing #{@current_resource.share_name}") do
        if recreateRequired
          delete_share
          create_share
        end

        set_share_permissions
      end
    else
      Chef::Log.debug("#{@current_resource.share_name} already set - nothing to do")
    end
  else
    converge_by("Creating #{@current_resource.share_name}") do
      create_share
      set_share_permissions
    end
  end
end

def load_current_resource
  @current_resource = Chef::Resource::WindowsShare.new(@new_resource.name)
  @current_resource.share_name(@new_resource.share_name)

  share = find_share_by_name @current_resource.share_name

  if share.nil?
    @current_resource.exists = false
  else
    @current_resource.exists = true
    @current_resource.path(share.Path)
    @current_resource.description(share.Description)
    share_permissions
  end
end

private

def share_permissions
  wmi = WIN32OLE.connect('winmgmts://')
  shares = wmi.ExecQuery("SELECT * FROM Win32_LogicalShareSecuritySetting WHERE name = '#{@current_resource.share_name}'")

  # The security descriptor is an output parameter
  sd = nil
  shares.ItemIndex(0).GetSecurityDescriptor(sd)
  sd = WIN32OLE::ARGV[0]

  read = []
  change = []
  full = []
  sd.DACL.each do |dacl|
    trustee = "#{dacl.Trustee.Domain}\\#{dacl.Trustee.Name}".downcase
    case dacl.AccessMask
    when ACCESS_FULL
      full.push(trustee)
    when ACCESS_CHANGE
      change.push(trustee)
    when ACCESS_READ
      read.push(trustee)
    else
      Chef::Log.warn "Unknown access mask #{dacl.AccessMask} for user #{trustee}. This will be lost if permissions are updated"
    end
  end

  @current_resource.full_users(full)
  @current_resource.change_users(change)
  @current_resource.read_users(read)
end

def find_share_by_name(name)
  wmi = WIN32OLE.connect('winmgmts://')
  shares = wmi.ExecQuery("SELECT * FROM Win32_Share WHERE name = '#{name}'")
  shares.Count == 0 ? nil : shares.ItemIndex(0)
end

def delete_share
  find_share_by_name(@new_resource.share_name).delete
end

def create_share
  raise "#{@new_resource.path} is missing or not a directory" unless ::File.directory? @new_resource.path

  # http://msdn.microsoft.com/en-us/library/aa389393(v=vs.85).aspx
  wmi = WIN32OLE.connect('winmgmts://')
  share = wmi.get('Win32_Share')
  r = share.create(win_friendly_path(@new_resource.path), # Path
                   @new_resource.share_name, # Share name
                   0, # Share type 0 = Disk
                   16_777_216, # Maximum allowed.  This is the 2008 R2 default.
                   @new_resource.description, # The description
                   nil, # The share password, unused.
                   nil) # The share security descriptor

  raise "Could not create share.  Win32_Share.create returned #{r}" unless r == 0
end

# set_share_permissions - Enforce the share permissions as dictated by the resource attributes
def set_share_permissions
  wmi = WIN32OLE.connect('winmgmts://')
  dacl = []

  @new_resource.full_users.each do |user|
    dacl.push(user_to_ace(wmi, user, ACCESS_FULL))
  end

  @new_resource.change_users.each do |user|
    dacl.push(user_to_ace(wmi, user, ACCESS_CHANGE))
  end

  @new_resource.read_users.each do |user|
    dacl.push(user_to_ace(wmi, user, ACCESS_READ))
  end

  security_descriptor = wmi.get('Win32_SecurityDescriptor')
  security_descriptor.DACL = dacl

  share = find_share_by_name(@new_resource.share_name)
  share.SetShareInfo(nil, @new_resource.description, security_descriptor)
end

def user_to_ace(wmi, fully_qualified_user_name, access)
  domain, user = fully_qualified_user_name.split('\\')
  unless domain && user
    raise "Invalid user entry #{fully_qualified_user_name}.  The user names must be specified as 'DOMAIN\\user'"
  end

  ace = wmi.get('Win32_ACE')
  trustee = wmi.get('Win32_Trustee')
  trustee.Name = user
  trustee.Domain = domain

  ace.AccessMask = access
  ace.AceFlags = 3 # OBJECT_INHERIT_ACE + CONTAINER_INHERIT_ACE
  ace.AceType = 0 # 0 allow, 1 deny
  ace.Trustee = trustee

  ace
end
