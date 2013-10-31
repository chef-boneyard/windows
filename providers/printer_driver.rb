#
# Author:: Derek Groh (<dgroh@arch.tamu.edu>)
# Cookbook Name:: windows
# Provider:: printer_driver
#
# Copyright 2013, Texas A&M
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
require 'mixlib/shellout'

action :create do
  if exists?
    Chef::Log.info("#{ new_resource.name } already exists - nothing to do.")
    new_resource.updated_by_last_action(false)
  else
    windows_batch "Creating print driver: #{ new_resource.name }" do
      code "rundll32 printui.dll PrintUIEntry /ia /m \"#{new_resource.name }\" /h \"#{ new_resource.environment}\" /v \"#{new_resource.version }\" /f \"#{new_resource.inf_path}\""
    end
  
    new_resource.updated_by_last_action(true)
  end
end

action :delete do
  if exists?
    windows_batch "Deleting print driver: #{ new_resource.name }" do
      code "rundll32 printui.dll PrintUIEntry /dd /m \"#{new_resource.name}\" /h \"#{new_resource.environment}\" /v \"#{new_resource.version}\""
    end

    new_resource.updated_by_last_action(true)
  else
    Chef::Log.info("#{ new_resource.name } doesn't exist - can't delete.")
    new_resource.updated_by_last_action(false)
  end
end
  
def exists?
  case new_resource.environment
  when "x64"
    check = Mixlib::ShellOut.new("powershell.exe \"Get-wmiobject -Class Win32_PrinterDriver -EnableAllPrivileges | where {$_.name -like '#{new_resource.name},3,Windows x64'} | fl name\"").run_command
  when "x86"
    check = Mixlib::ShellOut.new("powershell.exe \"Get-wmiobject -Class Win32_PrinterDriver -EnableAllPrivileges | where {$_.name -like '#{new_resource.name},3,Windows NT x86'} | fl name\"").run_command
  when "Itanium"
    check = Mixlib::ShellOut.new("powershell.exe \"Get-wmiobject -Class Win32_PrinterDriver -EnableAllPrivileges | where {$_.name -like '#{new_resource.name},3,Itanium'} | fl name\"").run_command
  else
    Chef::Log.error("Please use \"x64\", \"x86\" or \"Itanium\" as the environment type")
  end
  check.stdout.include? "#{new_resource.name}"
end