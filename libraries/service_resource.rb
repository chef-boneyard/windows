#
# Author:: Andrey Rotchev (<arotchev@wildapricot.com>)
# Cookbook Name:: windows
# Resource:: service
#
# Copyright:: 2015, WildApricot, Inc.
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

if RUBY_PLATFORM =~ /mswin|mingw32|windows/
  require 'chef/resource/windows_service'

  class Chef::Resource::WindowsCookbookService < Chef::Resource::WindowsService
    if Gem::Version.new(Chef::VERSION) >= Gem::Version.new('12')
      provides :windows_service, os: 'windows', override: true
    end

    state_attrs :enabled, :running, :exist, :configured

    def initialize(name, run_context = nil)
      super
      @exist = nil
      @configured = nil
      @action = :create
      @allowed_actions.push(:create, :delete, :config)
      @provider = Chef::Provider::WindowsCookbookService
    end

    def display_name(arg = nil)
      set_or_return(
        :display_name,
        arg,
        kind_of: [String]
      )
    end

    def description(arg = nil)
      set_or_return(
        :description,
        arg,
        kind_of: [String]
      )
    end

    def bin_path(arg = nil)
      set_or_return(
        :bin_path,
        arg,
        kind_of: [String]
      )
    end

    def recovery_first_failure(arg = nil)
      set_or_return(
        :recovery_first_failure,
        arg,
        kind_of:  [Symbol],
        equal_to: [:none, :reboot, :restart, :run_command]
      )
    end

    def recovery_second_failure(arg = nil)
      set_or_return(
        :recovery_second_failure,
        arg,
        kind_of:  [Symbol],
        equal_to: [:none, :reboot, :restart, :run_command]
      )
    end

    def recovery_subsequent_failures(arg = nil)
      set_or_return(
        :recovery_subsequent_failures,
        arg,
        kind_of:  [Symbol],
        equal_to: [:none, :reboot, :restart, :run_command]
      )
    end

    def restart_after_min(arg = nil)
      set_or_return(
        :restart_after_min,
        arg,
        kind_of: [Integer]
      )
    end

    def reset_fail_counter_days(arg = nil)
      set_or_return(
        :reset_fail_counter_days,
        arg,
        kind_of: [Integer]
      )
    end

    def host(arg = nil)
      set_or_return(
        :host,
        arg,
        kind_of: [String],
        default: 'localhost'
      )
    end

    def exist(arg = nil)
      set_or_return(
        :exist,
        arg,
        kind_of: [TrueClass, FalseClass]
      )
    end

    def configured(arg = nil)
      set_or_return(
        :configured,
        arg,
        kind_of: [TrueClass, FalseClass]
      )
    end
  end

  if Gem::Version.new(Chef::VERSION) < Gem::Version.new('12')
    # this wires up the cookbook version of the windows_service resource as Chef::Resource::WindowsService,
    # which is kinda hella janky
    Chef::Resource.send(:remove_const, :WindowsService) if defined? Chef::Resource::WindowsService
    Chef::Resource.const_set('WindowsService', Chef::Resource::WindowsCookbookService)
  else
    if Chef.respond_to?(:set_resource_priority_array)
      # this wires up the dynamic resource resolver to favor the cookbook version of windows_service over
      # the internal version (but the internal Chef::Resource::WindowsService is still the internal version
      # and a wrapper cookbook can override this e.g. for users that want to use the windows cookbook but
      # want the internal windows_service resource)
      Chef.set_resource_priority_array(:windows_service, [Chef::Resource::WindowsCookbookService], platform: 'windows')
    end
  end
end
