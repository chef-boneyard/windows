#
# Author:: Jason Field (jason.field@calastone.com)
# Cookbook:: windows
# Resource:: schannel
#
# Copyright:: 2019, Calastone Ltd.
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

property :use_strong_crypto, [true, false], default: true

action :configure do
  registry_key 'HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\.NETFramework\\v4.0.30319' do
    values [{
      name: 'SchUseStrongCrypto',
      type: :dword,
      data: new_resource.use_strong_crypto ? 1 : 0,
    }]
  end

  registry_key 'HKEY_LOCAL_MACHINE\\SOFTWARE\\Wow6432Node\\Microsoft\\.NETFramework\\v4.0.30319' do
    values [{
      name: 'SchUseStrongCrypto',
      type: :dword,
      data: new_resource.use_strong_crypto ? 1 : 0,
    }]
  end
end
