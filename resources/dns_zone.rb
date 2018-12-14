#
# Author:: Jason Field
# Cookbook:: windows
# Provider:: dns_zone
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
# Managed a DNS Zone

property :zone_name,          String, name_property: true
property :replication_scope,  String, default: 'Domain', required: false
property :server_type,        String, default: 'Domain', regex: /^(?:Domain|Standalone)$/i

action :create do
  windows_dsc_module 'xDnsServer' do
  end
  do_it 'Present'
end

action :delete do
  windows_dsc_module 'xDnsServer' do
  end
  do_it 'Absent'
end

action_class do
  def do_it(ensure_prop)
    if new_resource.server_type == 'Domain'
      dsc_resource "xDnsServerADZone #{new_resource.zone_name} #{ensure_prop}" do
        module_name 'xDnsServer'
        resource :xDnsServerADZone
        property :Ensure, ensure_prop
        property :Name, new_resource.zone_name
        property :ReplicationScope, new_resource.replication_scope
      end
    elsif new_resource.server_type == 'Standalone'
      dsc_resource "xDnsServerPrimaryZone #{new_resource.zone_name} #{ensure_prop}" do
        module_name 'xDnsServer'
        resource :xDnsServerPrimaryZone
        property :Ensure, ensure_prop
        property :Name, new_resource.zone_name
      end
    end
  end
end
