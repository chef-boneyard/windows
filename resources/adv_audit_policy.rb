#
# Author:: Seth Thoenen (<seththoenen@gmail.com>)
# Cookbook:: windows
# Resource:: adv_audit_policy
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

resource_name 'adv_audit_policy'

property :subcategory, String, name_property: true
property :policy_state, String, required: true, equal_to: ['success and failure', 'success', 'failure', 'no auditing']

action :manage do
  auditpol_command = 'auditpol.exe /set /subcategory:"' + new_resource.subcategory + '" '
  case new_resource.policy_state.downcase
  when 'success and failure'
    auditpol_command += '/failure:enable /success:enable'
  when 'success'
    auditpol_command += '/failure:disable /success:enable'
  when 'failure'
    auditpol_command += '/failure:enable /success:disable'
  when 'no auditing'
    auditpol_command += '/failure:disable /success:disable'
  end

  auditpol_guard_command = 'auditpol /get /subcategory:"' + new_resource.subcategory + '" /r'

  execute "Ensure '#{new_resource.subcategory}' is set to '#{new_resource.policy_state}'" do
    command auditpol_command
    not_if { shell_out(auditpol_guard_command).stdout.lines[1].split(',')[4].downcase.eql? new_resource.policy_state }
  end
end
