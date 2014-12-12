#
# Author:: Blair Hamilton (<blairham@me.com>)
# Cookbook Name:: windows
# Provider:: service
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

actions :create

attribute :service_name, :kind_of => String, :name_attribute => true
attribute :type, :kind_of => Symbol, :equal_to => [:own, :shared, :interact, :kernel, :filesys, :rec]
attribute :start, :kind_of => Symbol, :equal_to => [:boot, :system, :auto, :demand, :disabled, :'delayed-auto']
attribute :error, :kind_of => Symbol, :equal_to => [:normal, :severe, :cirtical, :ignore]
attribute :depends, :kind_of => String
attribute :tag, :kind_of => String
attribute :group, :kind_of => String
attribute :start_name, :kind_of => String
attribute :binary_path, :kind_of => String
attribute :display_name, :kind_of => String
attribute :password, :kind_of => String

attr_accessor :exists,:running

def initialize(name, run_context=nil)
  super
  @action = :create
end
