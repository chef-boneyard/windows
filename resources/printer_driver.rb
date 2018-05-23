#
# Author:: Derek Groh (<derekgroh@github.com>)
# Cookbook:: windows
# Resource:: printer_driver
#
# Copyright:: 2012-2017
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
# See here for more info:
# http://msdn.microsoft.com/en-us/library/windows/desktop/aa394492(v=vs.85).aspx

require 'mixlib/shellout'

property :driver_name, String, name_property: true, required: true
property :inf_path, String
property :printerenvironment, String, equal_to: ['Windows NT x86', 'Windows x64']

# Install the printer environment driver
def printer_driver_exists?(driver_name)
  check = Mixlib::ShellOut.new("powershell.exe \"Get-PrinterDriver | Where Name -Like \"#{new_resource.driver_name}\"")
  check.stdout.include? new_resource.driver_name
end

action :install do
  if @current_resource.exists
    Chef::Log.info "#{@new_resource} already exists - nothing to do."
  else
    converge_by("Create ${@new_resource}") do
        create_printer_driver
    end
  end
end

action :delete do
  if @current_resource.exists
    converge_by("Delete ${@new_resource}") do
      delete_printer_driver
    end
  else
    Chef::Log.info "#{@new_resource} doesn't exist - can't delete."
  end
end

action_class do
  def create_printer_driver
    cmd = "Add-PrinterDriver"
    cmd << " -InfPath '#{new_resource.infpath}'" if new_resource.infpath
    cmd << " -PrinterEnvironment '#{new_resource.printerenvironment}'" if new_resource.printerenvironment

    powershell_script "Creating printer driver: #{new_resource.driver_name}" do
      code cmd
    end
  end

  def delete_printer_driver
    powershell_script "Removing printer driver: #{new_resource.driver_name}" do
      code "Remove-PrinterDriver -Name \"#{new_resource.driver_name}\""
    end
  end
end
