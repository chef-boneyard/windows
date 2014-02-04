# -*- coding: utf-8 -*-
#
# Author:: Sölvi Páll Ásgeirsson (<solvip@gmail.com>)
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


require 'ruby-wmi'
require 'WIN32OLE'

ACCESS_FULL = 2032127
ACCESS_CHANGE = 1245631
ACCESS_READ = 1179817

action :delete do
  if @current_resource.exists
    Chef::Log.debug("Deleting share #{new_resource.name}")
    delete_share
    new_resource.updated_by_last_action(true)
  end
end

action :create do
  unless @new_resource.path and ::File.directory? @new_resource.path
    raise "#{@new_resource.path} missing or is not a directory - it makes no sense to continue"
  end
  
  unless @current_resource.exists
    Chef::Log.debug("Creating share #{new_resource.name}")
    create_share
    new_resource.updated_by_last_action(true)
  end

  set_share_permissions
end


def load_current_resource
  @current_resource = Chef::Resource::WindowsShare.new(@new_resource.name)
  @current_resource.name(@new_resource.name)
  @current_resource.path(@new_resource.path)
  
  @current_resource.exists = exists?
  
  @current_resource
end


private


def find_share_by_name(name)
  WMI::Win32_share.find(:first, :conditions => {:name => name})
end


def exists?
  if find_share_by_name(@new_resource.name)
    Chef::Log.debug("Found share #{@new_resource.name}")
    true
  else 
    false
  end
end


def delete_share
  find_share_by_name(@new_resource.name).delete
end

  
def create_share
  # http://msdn.microsoft.com/en-us/library/aa389393(v=vs.85).aspx
  wmi = WIN32OLE.connect("winmgmts://")
  share = wmi.get("win32_share")
  r = share.create(@new_resource.path, # Path
                   @new_resource.name, # Share name
                   0, # Share type
                   16777216, # Maximum allowed.  This is the 2008 R2 default.
                   nil, # The description
                   nil, # The share password, unused.
                   nil) # The share security descriptor

  unless r == 0
    raise "Could not create share.  Win32_share.create returned #{r}"
  end
end


# set_share_permissions - Enforce the share permissions as dictated by the resource attributes
def set_share_permissions
  wmi = WIN32OLE.connect("winmgmts://")
  dacl = []
  
  @new_resource.full_users.each do |user|
    dacl.push(user_to_ace(user, ACCESS_FULL))
  end

  @new_resource.change_users.each do |user|
    dacl.push(user_to_ace(user, ACCESS_CHANGE))
  end

  @new_resource.read_users.each do |user|
    dacl.push(user_to_ace(user, ACCESS_READ))
  end
  
  security_descriptor = wmi.get("Win32_SecurityDescriptor")
  security_descriptor.DACL = dacl
  
  share = find_share_by_name(@new_resource.name)
  share.SetShareInfo(nil, nil, security_descriptor)
end


def user_to_ace(fully_qualified_user_name, access)
  wmi = WIN32OLE.connect("winmgmts://")
  
  domain, user = fully_qualified_user_name.split("\\")
  unless domain and user
    raise "Invalid user entry #{fully_qualified_user_name}.  The user names must be specified as 'DOMAIN\\user'"
  end
  
  ace = wmi.get("Win32_ACE")
  trustee = wmi.get("Win32_Trustee")
  trustee.Name = user
  trustee.Domain = domain
  
  ace.AccessMask = access
  ace.AceFlags = 3 # ???
  ace.AceType = 0 # 0 allow, 1 deny
  ace.Trustee = trustee
  
  ace
end
