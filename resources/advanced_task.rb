#
# Author:: Baptiste Courtois (<b.courtois@criteo.com>)
# Cookbook Name:: windows
# Resource:: advanced_task
#
# Copyright:: 2015, Criteo.
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

require 'win32ole' if RUBY_PLATFORM =~ /mswin|mingw32|windows/

actions :create, :delete, :disable, :enable, :start, :stop, :update

attribute :task_name, kind_of: String, name_attribute: true, regex: [%r{^[^\/\:\*\?\<\>\|]+$}]
attribute :user, kind_of: String, default: 'SYSTEM'
attribute :group, kind_of: String, default: ''
attribute :password, kind_of: String, default: nil
attribute :force, kind_of: [TrueClass, FalseClass], default: false

def initialize(name, run_context = nil)
  super
  @action = :create
  @settings = Windows::TaskSchedulerHelper.new_ole_hash :settings
  @exec_actions = {}
  @triggers = {}

  run_level :limited
  logon_type :service_account
end

# See Run Level: http://msdn.microsoft.com/windows/desktop/aa382076
def run_level(arg = nil)
  unless arg.nil?
    @run_level = case arg
                 when Fixnum then arg
                 when :limited, :lua then 0
                 when :highest then 1
                 else fail ArgumentError, "Unknown run level: #{arg}"
                 end
  end
  @run_level
end

# See Logon Types: http://msdn.microsoft.com/windows/desktop/aa382075
def logon_type(arg = nil)
  unless arg.nil?
    @logon_type = case arg
                  when Fixnum then arg
                  when :none then 0
                  when :password then 1
                  when :s4u then 2
                  when :interactive_token then 3
                  when :group then 4
                  when :service_account then 5
                  when :interactive_token_or_password then 6
                  else fail ArgumentError, "Unknown logon type: #{arg}"
                  end
  end
  @logon_type
end

def settings(arg = nil)
  unless arg.nil?
    fail ArgumentError, 'Invalid settings. It must be a Hash!' unless arg.is_a? Hash
    fail ArgumentError, 'Invalid settings. Enabled must not be provided!' if arg.key? 'Enabled'
    @settings.merge! arg
  end
  @settings
end

def triggers(arg = nil)
  [arg].compact.flatten(1).each do |trigger|
    fail ArgumentError, 'Invalid triggers: if WIN32OLE object passed it must be an I*Trigger!' if trigger.is_a?(WIN32OLE) && !trigger.ole_type.to_s =~ /^I[A-z]+Trigger$/

    # Creates a new hash completed with default values and push it to triggers collection
    trigger_hash = Windows::TaskSchedulerHelper.new_ole_hash :trigger, trigger

    # Convert type symbols to int (See Trigger Types: http://msdn.microsoft.com/windows/desktop/aa383915)
    trigger_hash['Type'] = case trigger_hash['Type']
                           when Fixnum then trigger_hash['Type']
                           when :event then 0
                           when :time then 1
                           when :daily then 2
                           when :weekly then 3
                           when :monthly then 4
                           when :monthlydow then 5
                           when :idle then 6
                           when :registration then 7
                           when :boot then 8
                           when :logon then 9
                           when :session_state_change then 11
                           else fail ArgumentError, "Unknown trigger type: #{trigger_hash['Type']}"
                           end

    # Assigns an identifier to the trigger if none provided
    trigger_hash['Id'] = "trigger_#{@triggers.size}" if [nil, ''].include? trigger_hash['Path']
    @triggers[trigger_hash['Id']] = trigger_hash
  end
  @triggers
end

def exec_actions(arg = nil)
  [arg].compact.flatten(1).each do |action|
    fail ArgumentError, 'Invalid exec_actions: if WIN32OLE object passed it must be an IExecAction!' if action.is_a?(WIN32OLE) && action.ole_type.to_s != 'IExecAction'

    # Creates a new hash completed with default values
    action_hash = Windows::TaskSchedulerHelper.new_ole_hash :exec_action, action

    fail ArgumentError, 'Invalid exec_actions: "Type" must be 0 if provided!' if action_hash['Type'] != Windows::TaskSchedulerHelper::EXEC_ACTION_ID
    fail ArgumentError, 'Invalid exec_actions: "Path" must be provided as non-nil and non-empty value!' if [nil, ''].include? action_hash['Path']

    # Assigns an identifier to the action if none provided
    action_hash['Id'] = "exec_#{@exec_actions.size}" if action_hash['Id'].nil? || action_hash['Id'] == ''
    @exec_actions[action_hash['Id']] = action_hash
  end
  @exec_actions
end
