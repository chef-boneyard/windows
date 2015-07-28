#
# Author:: Baptiste Courtois (<b.courtois@criteo.com>)
# Cookbook Name:: windows
# Provider:: advanced_task
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

use_inline_resources

def whyrun_supported?
  true
end

action :create do
  if !task_exists? || task_need_update? || new_resource.force
    validate_logon_info
    converge_by "creating task #{new_resource}" do
      folder.RegisterTaskDefinition(new_resource.task_name,
                                    new_task_object,
                                    Windows::TaskSchedulerHelper::TASK_REGISTRATION_CREATE_OR_UPDATE,
                                    new_resource.user,
                                    new_resource.password,
                                    new_resource.logon_type)
    end
  else
    Chef::Log.info "#{new_resource} task already exists - nothing to do"
  end
end

action :delete do
  if task_exists?
    converge_by "deleting task #{new_resource}" do
      folder.DeleteTask new_resource.task_name, nil
    end
  else
    Chef::Log.debug "#{new_resource}: task doesn't exists - nothing to do"
  end
end

action :disable do
  if task_exists?
    if @current_task_object.Enabled
      converge_by "disabling task #{new_resource}" do
        @current_task_object.Enabled = false
      end
    else
      Chef::Log.debug "#{new_resource}: already disabled - nothing to do"
    end
  else
    Chef::Log.debug "#{new_resource}: task doesn't exist - nothing to do"
  end
end

action :enable do
  if task_exists?
    if @current_task_object.Enabled
      Chef::Log.debug "#{new_resource} already enabled - nothing to do"
    else
      converge_by "enabling task #{new_resource}" do
        @current_task_object.Enabled = true
      end
    end
  else
    fail Errno::ENOENT, "#{new_resource}: task does not exist, cannot enable"
  end
end

action :start do
  if task_exists?
    if task_running?
      Chef::Log.info "#{new_resource} task is currently running, skipping run"
    else
      converge_by "running task #{new_resource}" do
        @current_task_object.Run nil
      end
    end
  else
    Chef::Log.debug "#{new_resource} task doesn't exists - nothing to do"
  end
end

action :stop do
  if task_exists?
    if task_running?
      Chef::Log.debug "#{new_resource} is not running - nothing to do"
    else
      converge_by "stopping task #{new_resource}" do
        @current_task_object.Stop 0
      end
    end
  else
    fail Errno::ENOENT, "#{new_resource}: task does not exist, cannot end"
  end
end

action :update do
  if task_exists?
    if task_need_update?
      validate_logon_info

      converge_by "updating task #{new_resource}" do
        folder.RegisterTaskDefinition(new_resource.task_name,
                                      new_task_object,
                                      Windows::TaskSchedulerHelper::TASK_REGISTRATION_UPDATE,
                                      new_resource.user,
                                      new_resource.password,
                                      new_resource.logon_type)
      end
    else
      Chef::Log.info "#{new_resource} task already exists - nothing to do"
    end
  else
    Chef::Log.debug "#{new_resource} task doesn't exists - nothing to do"
  end
end

def load_current_resource
  @current_resource = Chef::Resource::WindowsAdvancedTask.new new_resource.name
  @current_resource.task_name new_resource.task_name

  Chef::Log.debug "looking for existing tasks '#{new_resource.task_name}'"
  @current_task_object = folder.GetTask new_resource.task_name

  @current_task_object.Definition.tap do |task_def|
    # Convert all actions to hash and add them as exec_actions to the current resource
    task_def.Actions.each do |action|
      # Do not fail when existing task has unsupported action
      next if action.Type != Windows::TaskSchedulerHelper::EXEC_ACTION_ID
      @current_resource.exec_actions action
    end

    # Convert all triggers to hash and add them as triggers to the current resource
    task_def.Triggers.each do |trigger|
      @current_resource.triggers trigger
      # Handle the optional 'StartBoundary' property, take the existing one if not provided in the new resource
      new_trigger = new_resource.triggers[trigger.Id]
      new_trigger['StartBoundary'] = trigger.StartBoundary if new_trigger && (new_trigger['StartBoundary'].nil? || new_trigger['StartBoundary'] == '')
    end

    # Populate the principal/security info
    task_def.Principal.tap do |principal|
      @current_resource.user principal.UserId if principal.UserId
      @current_resource.group principal.GroupId if principal.GroupId
      @current_resource.run_level principal.RunLevel
      @current_resource.logon_type principal.LogonType
    end

    # Populate task settings, but reject Enabled property because this is handled by enabled/disabled action
    @current_resource.settings Windows::TaskSchedulerHelper.ole_to_hash(task_def.Settings).reject { |k| k == 'Enabled' }
  end

rescue WIN32OLERuntimeError => e
  # Code 80070002 means task does not exist
  # Code 80070003 means that part of the path does not exist
  # Another code means a real error
  raise unless e.to_s =~ /method `GetTask': \)\s+OLE error code:8007000[23]/
end

private

def new_task_object
  @new_task_object ||= scheduler.NewTask(0).tap do |task|
    task.RegistrationInfo.Author = 'Chef'

    task.Principal.tap do |principal|
      principal.UserId = new_resource.user
      principal.GroupId = new_resource.group
      principal.RunLevel = new_resource.run_level
      principal.LogonType = new_resource.logon_type
    end

    # Hydrate task settings
    Windows::TaskSchedulerHelper.hydrate_ole_object task.Settings, new_resource.settings

    # Hydrate task triggers
    task.Triggers.tap do |triggers|
      new_resource.triggers.each do |_, data|
        trigger = triggers.Create data['Type']
        Windows::TaskSchedulerHelper.hydrate_ole_object trigger, data
        # Handle option 'StartBoundary' property: set to DateTime.now if not provided
        trigger.StartBoundary = DateTime.now.strftime('%Y-%m-%dT%H:%M:%S') if data['StartBoundary'].nil? || data['StartBoundary'] == ''
      end
    end

    # Hydrate task actions
    task.Actions.tap do |actions|
      new_resource.exec_actions.each do |_, data|
        action = actions.Create Windows::TaskSchedulerHelper::EXEC_ACTION_ID
        Windows::TaskSchedulerHelper.hydrate_ole_object action, data
      end
    end
  end
end

def scheduler
  @scheduler ||= WIN32OLE.new('Schedule.Service').tap(&:connect)
end

def folder
  @folder ||= scheduler.GetFolder '\\'
end

def task_exists?
  @current_resource && !@current_task_object.nil?
end

def task_running?
  Windows::TaskSchedulerHelper::TASK_STATE_RUNNING_ID == @current_task_object.state
end

def task_need_update?
  @current_resource.logon_type != new_resource.logon_type ||
    @current_resource.exec_actions != new_resource.exec_actions ||
    @current_resource.triggers != new_resource.triggers ||
    @current_resource.settings != new_resource.settings ||
    !are_equal_ci(@current_resource.user, new_resource.user) ||
    !are_equal_ci(@current_resource.group, new_resource.group)
end

def are_equal_ci(str1, str2)
  case str1
  when String then str2.nil? ? false : str1.casecmp(str2).zero?
  else str1 == str2
  end
end

def validate_logon_info
  case new_resource.logon_type
  when 4, :group
    # Group must be provided
    fail 'Group must be provided and non-empty with logon_type "group"!' unless [nil, ''].include? new_resource.group
  when 5, :service_account
    # Password must be nil
    fail 'Password must not be provided when using a service account!' unless new_resource.password.nil?
    # Group must be nil
    fail 'Group must not be provided or empty when using a service account!' unless [nil, ''].include? new_resource.group
    # User must be part of SERVICE_USERS
    fail "Service account should be one of the following: #{Windows::TaskSchedulerHelper::SERVICE_USERS.join ', '}!" unless Windows::TaskSchedulerHelper::SERVICE_USERS.include? new_resource.user.upcase
  when 1, :password, 6, :interactive_token_or_password
    # Password must be provided
    fail 'Password must be provided and non-empty with logon_type "password" or "interactive_token_or_password"!' if [nil, ''].include? new_resource.password
  end
  # User and Group can't be combined
  fail 'Both "user" and "group" are provided!' unless [nil, ''].include?(new_resource.user) || [nil, ''].include?(new_resource.group)
end
