#
# Author:: Jason Field
# Cookbook Name:: windows
# Resource:: dfs
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
# disable use of FQDN. https://docs.microsoft.com/en-us/powershell/module/dfsn/set-dfsnserverconfiguration?view=win10-ps

property :use_fqdn, [TrueClass, FalseClass], default: false

action :configure do
  powershell_script 'Configure DFS Server Settings' do
    code <<-EOH
      Set-DfsnServerConfiguration -ComputerName "#{ENV['COMPUTERNAME']}" -UseFqdn $#{new_resource.use_fqdn}
    EOH
    not_if "(Get-DfsnServerConfiguration -ComputerName '#{ENV['COMPUTERNAME']}').UseFqdn -eq $#{new_resource.use_fqdn}"
  end
end
