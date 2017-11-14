#
# Author:: Paul Morton (<pmorton@biaprotect.com>)
# Cookbook:: windows
# Resource:: auto_run
#
# Copyright:: 2011-2017, Business Intelligence Associates, Inc.
# Copyright:: 2017, Chef Software, Inc.
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

property :program, String
property :args, String
property :root,
         Symbol,
         equal_to: %i(machine user),
         coerce: proc { |x| x.to_sym },
         default: :machine

action :create do
  registry_key registry_path do
    values [{
      name: new_resource.name,
      type: :string,
      data: "\"#{new_resource.program}\" #{new_resource.args}",
    }]
    action :create
  end
end

action :remove do
  registry_key registry_path do
    values [{
      name: new_resource.name,
      type: :string,
      data: '',
    }]
    action :delete
  end
end

action_class do
  def registry_path
    { machine: 'HKLM', user: 'HKCU' }[new_resource.root] + \
      '\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run'
  end
end
