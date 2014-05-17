#
# Author:: Blair Hamilton (<blairham@me.com>)
# Cookbook Name:: windows
# Provider:: firewall
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

actions :add, :set, :delete

attribute :rule_name, :kind_of => String, :name_attribute => true
attribute :group, :kind_of => [TrueClass, FalseClass], :default => true, :equal_to => [true, false]
attribute :firewall_action, :kind_of => Symbol, :default => :allow, :equal_to => [:allow, :block]
attribute :direction, :kind_of => Symbol, :default => :in, :equal_to => [:in, :out]
attribute :profile, :kind_of => Array, :default => nil
attribute :protocol, :kind_of => Symbol, :default => :tcp, :equal_to => [:tcp, :udp, :icmpv4, :icmpv6, :any]
attribute :ports, :kind_of => Array, :default => [80]
attribute :enable, :kind_of => Symbol, :default => nil, :equal_to => [:yes, :no]

attr_accessor :created

def initialize(name, run_context=nil)
  super
  @action = :add
end
