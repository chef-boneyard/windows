#
# Author:: Baptiste Courtois (<b.courtois@criteo.com>)
# Cookbook Name:: windows
# Library:: windows_taskscheduler_helper
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

require 'win32ole' if RUBY_PLATFORM =~ /mswin|mingw32|windows/

module Windows
  # Provides some methods to easily interact with Task Scheduler OLE objects
  module TaskSchedulerHelper
    SERVICE_USERS = ['NT AUTHORITY\SYSTEM', 'SYSTEM', 'NT AUTHORITY\LOCALSERVICE', 'NT AUTHORITY\NETWORKSERVICE']

    # See Action Types http://msdn.microsoft.com/windows/desktop/aa383553)
    EXEC_ACTION_ID = 0
    # See Task State (http://msdn.microsoft.com/windows/desktop/aa382097)
    TASK_STATE_RUNNING_ID = 3
    # See TASK_CREATION constants (http://msdn.microsoft.com/windows/desktop/aa382538)
    TASK_REGISTRATION_CREATE_OR_UPDATE = 0x6
    TASK_REGISTRATION_UPDATE = 0x4

    # Creates a new hash based with default values of the specified type and hydrated with provided data
    def self.new_ole_hash(type, data = nil)
      Chef::Mixin::DeepMerge.merge default_values(type), case data
                                                         when Hash, nil then data
                                                         when WIN32OLE then ole_to_hash(data)
                                                         else fail 'Unsupported data type. Supported types are: [Hash, WIN32OLE]'
                                                         end
    end

    # Creates a hash from of an OLE object
    def self.ole_to_hash(ole_object)
      # Extracts ole properties names
      Hash[ole_object.ole_get_methods.map(&:to_s).map do |property_name|
        # XmlText is special and useless for our work!
        next if property_name == 'XmlText'

        value = ole_object.send property_name.to_sym
        [property_name, value.is_a?(WIN32OLE) ? ole_to_hash(value) : value]
      end]
    end

    # Hydrates an OLE object from a hash
    def self.hydrate_ole_object(ole_object, hash)
      hash.each do |key, value|
        if value.is_a? Hash
          sub_object = ole_object.send key.to_sym
          hydrate_ole_object sub_object, value
        else
          ole_object.setproperty key, value if ole_object.ole_put_methods.any? { |m| m.to_s == key }
        end
      end
    end

    private

    def self.default_values(type)
      case type
      when :trigger then default_trigger
      when :exec_action then default_exec_action
      when :settings then default_settings
      else fail "Invalid type `#{type}', supported types are [:trigger, :exec_action, :settings]"
      end
    end

    def self.default_exec_action
      {
        'Arguments' => '',
        'Type' => 0,
        'WorkingDirectory' => ''
      }
    end

    def self.default_trigger
      {
        'DaysInterval' => 1,
        'DaysOfMonth' => 0,
        'DaysOfWeek' => 0,
        'Delay' => '',
        'Enabled' => true,
        'EndBoundary' => '',
        'ExecutionTimeLimit' => '',
        'MonthsOfYear' => 0,
        'RandomDelay' => '',
        'Repetition' => { 'Interval' => '', 'Duration' => '', 'StopAtDurationEnd' => false },
        'RunOnLastDayOfMonth' => false,
        'RunOnLastWeekOfMonth' => false,
        'StartBoundary' => '',
        'StateChange' => 0,
        'Subscription' => '',
        'UserId' => '',
        'ValueQueries' => '',
        'WeeksInterval' => 1,
        'WeeksOfMonth' => 0
      }
    end

    def self.default_settings
      {
        'AllowDemandStart' => true,
        'AllowHardTerminate' => true,
        'Compatibility' => 2,
        'DeleteExpiredTaskAfter' => '',
        'DisallowStartIfOnBatteries' => true,
        'ExecutionTimeLimit' => 'PT72H',
        'Hidden' => false,
        'IdleSettings' => { 'IdleDuration' => 'PT10M', 'WaitTimeout' => 'PT1H', 'StopOnIdleEnd' => true, 'RestartOnIdle' => false },
        'MultipleInstances' => 2,
        'NetworkSettings' => { 'Id' => '', 'Name' => '' },
        'Priority' => 7,
        'RestartCount' => 0,
        'RestartInterval' => '',
        'RunOnlyIfIdle' => false,
        'RunOnlyIfNetworkAvailable' => false,
        'StartWhenAvailable' => false,
        'StopIfGoingOnBatteries' => true,
        'WakeToRun' => false
      }
    end
  end
end
