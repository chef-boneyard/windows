#
# Author:: Paul Mooring (<paul@opscode.com>)
# Cookbook Name:: windows
# Provider:: task
#
# Copyright:: 2012, Opscode, Inc.
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

require 'chef/mixin/shell_out'
include Chef::Mixin::ShellOut

action :create do
  if @current_resource.exists
    Chef::Log.info "#{@new_resource} task already exists - nothing to do"
  else
    if node["platform_version"] =~ /^5/
      action_create_v1 # 2003/xp
    else
      action_create_v2 # vista and up
    end

    # update resource
    @new_resource.updated_by_last_action true
    Chef::Log.info "#{@new_resource} task created"
  end
end

action :run do
  if @current_resource.exists
    if @current_resource.status == :running
      Chef::Log.info "#{@new_resource} task is currently running, skipping run"
    else
      # run action based on current platform
      if node["platform_version"] =~ /^5/
        action_run_v1 # 2003/xp
      else
        action_run_v2 # vista and up
      end

      # update resource
      @new_resource.updated_by_last_action true
      Chef::Log.info "#{@new_resource} task ran"
    end
  else
    Chef::Log.debug "#{@new_resource} task doesn't exists - nothing to do"
  end

end

action :change do
  if @current_resource.exists
    if node["platform_version"] =~ /^5/
      action_change_v1 # 2003/xp
    else
      action_change_v2 # vista and up
    end

    # update resource
    @new_resource.updated_by_last_action true
    Chef::Log.info "Change #{@new_resource} task ran"
  else
    Chef::Log.debug "#{@new_resource} task doesn't exists - nothing to do"
  end
end

action :delete do
  if @current_resource.exists
    if node["platform_version"] =~ /^5/
      action_delete_v1 # 2003/xp
    else
      action_delete_v2 # vista and up
    end

    # update resource
    @new_resource.updated_by_last_action true
    Chef::Log.info "#{@new_resource} task deleted"
  else
    Chef::Log.debug "#{@new_resource} task doesn't exists - nothing to do"
  end
end

def load_current_resource
  @current_resource = Chef::Resource::WindowsTask.new(@new_resource.name)
  @current_resource.name(@new_resource.name)

  if node["platform_version"] =~ /^5/
    task_hash = load_task_hash_v1(@current_resource.name)
  else
    task_hash = load_task_hash_v2(@current_resource.name)
  end

  if task_hash[:TaskName] == '\\' + @new_resource.name
    @current_resource.exists = true
    if task_hash[:Status] == "Running"
      @current_resource.status = :running
    end
    @current_resource.cwd(task_hash[:Folder])
    @current_resource.command(task_hash[:TaskToRun])
    @current_resource.user(task_hash[:RunAsUser])
  end if task_hash.respond_to? :[]
end

private

# Task Scheduler 1.0 support
def load_task_hash_v1(task_name)
  Chef::Log.debug "looking for existing tasks"

  require "win32/taskscheduler"
  task = {}
  task_scheduler = task_scheduler_v1

  if task_scheduler.enum.include?("#{task_name}.job")
    task_scheduler.activate(task_name)
    task[:TaskName] = "\\#{task_name}"
    task[:Folder] = task_scheduler.working_directory
    task[:TaskToRun] = "#{task_scheduler.application_name} #{task_scheduler.parameters}".strip
    task[:RunAsUser] = task_scheduler.account_information
  end

  task
end

def action_create_v1
  # prepare trigger
  now = Time.now + 5
  trigger = {
    :start_year => now.year,
    :start_month => now.month,
    :start_day => now.day,
    :start_hour => now.hour,
    :start_minute => now.min
  }

  case @new_resource.frequency
  when :minute
    trigger[:trigger_type] = ::Win32::TaskScheduler::ONCE
    trigger[:minutes_interval] = @new_resource.frequency_modifier
    trigger[:minutes_duration] = 60 * 24 # 24h for task to complete - must be given AND bigger than minutes_interval
  when :hourly
    trigger[:trigger_type] = ::Win32::TaskScheduler::ONCE
    trigger[:minutes_interval] = @new_resource.frequency_modifier * 60
    trigger[:minutes_duration] = 60 * 24 # 24h for task to complete - must be given AND bigger than minutes_interval
  when :daily
    trigger[:trigger_type] = ::Win32::TaskScheduler::DAILY
    trigger[:type] = {:days_interval => @new_resource.frequency_modifier}
  when :monthly
    trigger[:trigger_type] = ::Win32::TaskScheduler::ONCE
    trigger[:minutes_interval] = @new_resource.frequency_modifier * 60 * 24 * 30 # 60 minutes per hour, 24 hours per day, 30 days (avg) per month
    trigger[:minutes_duration] = trigger[:minutes_interval] * 2 # must be given AND bigger than minutes_interval
  when :once
    trigger[:trigger_type] = ::Win32::TaskScheduler::ONCE
  when :on_logon
    raise ArgumentError, "on_logon is unsupported for 2003/xp"
  when :onstart
    raise ArgumentError, "onstart is unsupported for 2003/xp"
  when :on_idle
    raise ArgumentError, "on_idle is unsupported for 2003/xp"
  end

  # set application and parameters
  task_scheduler = task_scheduler_v1(true)
  task_scheduler.new_work_item(@new_resource.name, trigger)
  task_scheduler.application_name, task_scheduler.parameters = split_command(@new_resource.command)
  task_scheduler.working_directory = @new_resource.cwd if @new_resource.cwd

  # set user & password
  if @new_resource.user && @new_resource.password
    task_scheduler.set_account_information(@new_resource.user, @new_resource.password)
  elsif (@new_resource.user and !@new_resource.password) || (@new_resource.password and !@new_resource.user)
    Chef::Log.fatal "#{@new_resource.name}: Can't specify user or password without both!"
  else
    # else use SYSTEM account
    task_scheduler.set_account_information("", "")
  end

  # save task
  begin
    task_scheduler.save
  rescue ::Win32::TaskScheduler::Error => e
    Chef::Log.debug "#{@new_resource.name}: Error: #{e.message}"
    Chef::Log.fatal "#{@new_resource.name}: Can't create scheduled task"
  end
end

def action_run_v1
  task_scheduler = task_scheduler_v1
  task_scheduler.activate(@current_resource.name)
  task_scheduler.run
end

def action_change_v1
  task_scheduler = task_scheduler_v1
  task_scheduler.activate(@current_resource.name)
  task_scheduler.application_name, task_scheduler.parameters = split_command(@new_resource.command) if @new_resource.command

  if @new_resource.user && @new_resource.password
    task_scheduler.set_account_information(@new_resource.user, @new_resource.password)
  elsif (@new_resource.user and !@new_resource.password) || (@new_resource.password and !@new_resource.user)
    Chef::Log.fatal "#{@new_resource.name}: Can't specify user or password without both!"
  elsif task_scheduler.account_information == ""
    # "" is equal to SYSTEM account - but if you chage via api, you have set SYSTEM explicity
    # otherwise - for unknown reasons - it sets user to run task as to current user...
    task_scheduler.set_account_information("", "")
  end

  # save task
  begin
    task_scheduler.save
  rescue ::Win32::TaskScheduler::Error => e
    Chef::Log.debug "#{@new_resource.name}: Error: #{e.message}"
    Chef::Log.fatal "#{@new_resource.name}: Can't change scheduled task"
  end
end

def action_delete_v1
  task_scheduler = task_scheduler_v1
  task_scheduler.delete(@current_resource.name)
end

def task_scheduler_v1(force=false)
  require "win32/taskscheduler"
  if force
    @task_scheduler = ::Win32::TaskScheduler.new
  else
    @task_scheduler ||= ::Win32::TaskScheduler.new
  end
end

# it splits command into application and parameters part
# returns: array in form: [application_name, parameters]
def split_command(command)
  case command
  when /^['"](.+?)['"]\s+(.+)/ then [$1, $2] # command in quotation marks with params
  when /^(\S+)\s+(.+)/ then [$1, $2] # command without quotation marks with params
  else [command, ""] # in any other case - just command, without params
  end
end

# Task Scheduler 2.0 support
def load_task_hash_v2(task_name)
  Chef::Log.debug "looking for existing tasks"

  require "win32ole"
  task = {}
  service = WIN32OLE.new("Schedule.Service")
  service.Connect

  begin
    root_folder = service.GetFolder("\\")
    registered_task = root_folder.GetTask("\\#{task_name}")
    task_definition = registered_task.Definition
  rescue WIN32OLERuntimeError => e
    # no such task - ignore!
  else
    task[:TaskName] = "\\#{task_name}"
    task[:Status] = case registered_task.State
      when 0 then "Unknown" # TASK_STATE_UNKONWN
      when 1 then "Disabled" # TASK_STATE_DISABLED
      when 2 then "Queued" # TASK_STATE_QUEUED
      when 3 then "Ready" # TASK_STATE_READY
      when 4 then "Running" # TASK_STATE_RUNNING
      end

    # get actions
    task_definition.Actions.each do |action|
      if action.Type == 0 # TYPE_ACTION_EXEC
        task[:TaskToRun] = "#{action.Path} #{action.Arguments}".strip
        task[:Folder] = action.WorkingDirectory
        break
      end
    end

    # get user
    task[:RunAsUser] = task_definition.Principal.UserId
    task[:RunLevel] = case task_definition.Principal.RunLevel
      when 0 then :limited # TASK_RUNLEVEL_LUA
      when 1 then :highest # TASK_RUNLEVEL_HIGHEST
      end

    # get triggers
    task_definition.Triggers.each do |trigger|
      case trigger.Type
      when 1 # TASK_TRIGGER_TIME
        case trigger.Repetition.Interval
        when ""
          frequency, frequency_modifier = :once, nil
        when /^P.*T(\d+)H$/
          frequency, frequency_modifier = :hourly, $1.to_i
        when /^P.*T(\d+H)?(\d+M)$/
          hours =   ($1.to_s.chop || 0).to_i
          minutes =   ($2.to_s.chop || 0).to_i
          frequency, frequency_modifier = :minute, hours*60 + minutes
        end
      when 2 # TASK_TRIGGER_DAILY
        frequency, frequency_modifier = :daily, trigger.DaysInterval
      when 3 # TASK_TRIGGER_WEEKLY
        frequency, frequency_modifier = :weekly, trigger.WeeksInterval
      when 4 # TASK_TRIGGER_MONTHLY
        # count numer of bits set to 1 in MonthsOfYear property
        months_count = trigger.MonthsOfYear.to_s(2).split(//).inject(0) { |s,i| s + i.to_i }
        frequency, frequency_modifier = :monthly, months_count % 12
      when 6 # TASK_TRIGGER_IDLE
        frequency, frequency_modifier = :on_idle, nil
      when 8 # TASK_TRIGGER_BOOT
        frequency, frequency_modifier = :on_start, nil
      when 9 # TASK_TRIGGER_LOGON
        frequency, frequency_modifier = :on_logon, nil
      end

      task[:Frequency] = frequency
      task[:FrequencyModifier] = frequency_modifier

      break
    end
  end

  task
end

def action_create_v2
  use_force = @new_resource.force ? '/F' : ''
  cmd =  "schtasks /Create #{use_force} /TN \"#{@new_resource.name}\" "
  schedule  = case @new_resource.frequency
    when :on_logon then "ONLOGON"
    else @new_resource.frequency
    end
  cmd += "/SC #{schedule} "
  cmd += "/ST #{(Time.now + 60).strftime("%H:%m")} " if @new_resource.frequency == :once
  cmd += "/MO #{@new_resource.frequency_modifier} " if [:minute, :hourly, :daily, :weekly, :monthly].include?(@new_resource.frequency)
  cmd += "/TR \"#{@new_resource.command}\" "
  if @new_resource.user && @new_resource.password
    cmd += "/RU \"#{@new_resource.user}\" /RP \"#{@new_resource.password}\" "
  elsif (@new_resource.user and !@new_resource.password) || (@new_resource.password and !@new_resource.user)
    Chef::Log.fatal "#{@new_resource.name}: Can't specify user or password without both!"
  end
  cmd += "/RL HIGHEST " if @new_resource.run_level == :highest
  shell_out!(cmd, {:returns => [0]})
end

def action_run_v2
  cmd = "schtasks /Run /TN \"#{@current_resource.name}\""
  shell_out!(cmd, {:returns => [0]})
end

def action_change_v2
  cmd =  "schtasks /Change /TN \"#{@current_resource.name}\" "
  cmd += "/TR \"#{@new_resource.command}\" " if @new_resource.command
  if @new_resource.user && @new_resource.password
    cmd += "/RU \"#{@new_resource.user}\" /RP \"#{@new_resource.password}\" "
  elsif (@new_resource.user and !@new_resource.password) || (@new_resource.password and !@new_resource.user)
    Chef::Log.fatal "#{@new_resource.name}: Can't specify user or password without both!"
  end
  shell_out!(cmd, {:returns => [0]})
end

def action_delete_v2
  use_force = @new_resource.force ? '/F' : ''
  cmd = "schtasks /Delete #{use_force} /TN \"#{@current_resource.name}\""
  shell_out!(cmd, {:returns => [0]})
end