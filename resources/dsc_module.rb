#
# Author::    Jason Field
# Cookbook::  windows
# Provider::  dsc_resource
#
# Copyright:: 2018, Calastone Ltd.
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
# Installs a DSC module from NuGet

property :module_name, String, name_property: true

installed_modules = Set.new

action :install do
  # we only need to load a module once per run
  unless installed_modules.include?(new_resource.module_name)
    proxy = "-Proxy #{ENV['http_proxy']}" unless ENV['http_proxy'].nil?
    powershell_script 'Install NuGet provider' do
      code <<-EOH
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force #{proxy}
        if($env:http_proxy -ne $null)
          {
            # we're behind a proxy. Manually register nuget
            [system.net.webrequest]::defaultwebproxy = new-object system.net.webproxy($env:http_proxy)
            Register-PSRepository -Default
          }
      EOH
      only_if '(Get-PackageProvider | where Name -eq "NuGet") -eq $null'
    end

    # there's a bug in Get-PackageProvider that sets up a pending reboot
    # see https://github.com/OneGet/oneget/issues/179
    # the latest package manager fixes it
    # we have to check both installed modules and the base module version
    # requires NuGet to be installed
    pm = powershell_script 'Update Package Manager module' do
      code <<-EOH
        Install-Module -Name PackageManagement -MinimumVersion 1.1.0.0 -Force #{proxy}
      EOH
      only_if <<-EOH
        ((Get-InstalledModule | where { $_.Version -ge "1.1.0.0" `
          -and $_.Name -eq "PackageManagement" }) -eq $null) `
        -and ((Get-Module -name "PackageManagement" | where Version -ge "1.1.0.0") -eq $null)
      EOH
    end

    powershell_script "Install #{new_resource.module_name} module" do
      code <<-EOH
        Install-Module -Name #{new_resource.module_name} -Force #{proxy}
      EOH
      only_if "(Get-InstalledModule | where Name -eq \"#{new_resource.module_name}\") -eq $null"
    end

    # the PM update won't fix the 1st run so we need to check for the registry key
    registry_key 'Clean up after Get-PackageProvider' do
      key    'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager'
      values [{ name: 'PendingFileRenameOperations', type: :multi_string, data: '' }]
      action :delete
      only_if { pm.updated_by_last_action? }
    end

    installed_modules.add(new_resource.module_name)
  end
end
