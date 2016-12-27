# -*- coding: utf-8 -*-
#
# Author:: Sölvi Páll Ásgeirsson (<solvip@gmail.com>), Richard Lavey (richard.lavey@calastone.com)
# Cookbook Name:: windows
# Resource:: share
#
# Copyright:: 2014, Sölvi Páll Ásgeirsson.
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

actions :create, :delete
default_action :create

attribute :share_name, kind_of: String, name_attribute: true
attribute :path, kind_of: String
attribute :description, kind_of: String, default: ''
attribute :full_users, kind_of: Array, default: []
attribute :change_users, kind_of: Array, default: []
attribute :read_users, kind_of: Array, default: []

attr_accessor :exists
