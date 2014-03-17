#
# Author:: Derek Groh (<dgroh@arch.tamu.edu>)
# Cookbook Name:: windows
# Provider:: printer_driver
#
# Copyright 2013, Texas A&M
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#
require 'mixlib/shellout'

action :install do
  if driver_exists?
    Chef::Log.info("#{ new_resource.name } already exists - nothing to do.")
    new_resource.updated_by_last_action(false)
  else
    windows_batch "Creating print driver: #{ new_resource.name }" do
      code "rundll32 printui.dll PrintUIEntry /ia /m \"#{ new_resource.name }\" /h \"#{ new_resource.architecture}\" /f \"#{ new_resource.inf_path}\""
    end
    Chef::Log.info("#{ new_resource.name } installed.")
    new_resource.updated_by_last_action(true)
  end
end

action :remove do
  if driver_exists?
    windows_batch "Deleting print driver: #{ new_resource.name }" do
      code "rundll32 printui.dll PrintUIEntry /dd /m \"#{ new_resource.name}\" /h \"#{new_resource.architecture }\""
    end
    Chef::Log.info("#{ new_resource.name } uninstalled.")
    new_resource.updated_by_last_action(true)
  else
    Chef::Log.info("#{ new_resource.name } doesn't exist - can't delete.")
    new_resource.updated_by_last_action(false)
  end
end
  
def driver_exists?
  check = "Mixlib::ShellOut.new(\"powershell.exe \"Get-wmiobject -Class Win32_PrinterDriver -EnableAllPrivileges | where {$_.name -like '#{ new_resource.name},3,"
  case new_resource.architecture
  when "x64"
    check << "Windows x64"
  when "x86"
    check << "Windows NT x86"
  when "Itanium"
    check << "Itanium"
  else
    Chef::Log.error("Please use \"x64\", \"x86\" or \"Itanium\" as the architecture type")
  end
  check << "'} | fl name\"\").run_command"
  check.stdout.include? "#{ new_resource.name }"
end