#
# Author:: Jason Field
# Cookbook Name:: windows
# Resource:: clone_registry_key
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
# Clones the supplied registry key

property :target_key_path, String, name_property: true
property :target_key, String, required: true
property :source_key_path, String, required: true
property :source_key, String, required: true

action :create do
  # get the value of the source key
  v = registry_get_values(new_resource.source_key_path)
      .select { |x| x[:name] == new_resource.source_key }[0]
  registry_key new_resource.target_key_path do
    values [{
      name: new_resource.target_key,
      type: v[:type],
      data: v[:data],
    }]
  end
end
