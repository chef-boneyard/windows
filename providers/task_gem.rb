#
# Author:: Grzegorz Marszalek <graf0@post.pl>
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

# Task Scheduler 1.0 support - used on xp/2003
require 'chef/mixin/shell_out'
include Chef::Mixin::ShellOut

# Support whyrun
def whyrun_supported?
  true
end

action :create do
  if @current_resource.exists
    Chef::Log.debug "Task #{@new_resource} already exists"
  else
    converge_by("Create task #{@new_resource}") do
      # prepare trigger, start in 5s from now
      now = Time.now + 5
      trigger = {
        :start_year   => now.year,
        :start_month  => now.month,
        :start_day    => now.day,
        :start_hour   => now.hour,
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
      task_scheduler.new_work_item(@new_resource.name, trigger)
      task_scheduler.application_name, task_scheduler.parameters = split_command(@new_resource.command)
      task_scheduler.working_directory = @new_resource.cwd if @new_resource.cwd

      # finish
      set_user_and_password
      save_task
    end
  end
end

action :run do
  if @current_resource.exists
    if @current_resource.status == :running
      Chef::Log.info "#{@new_resource} task is currently running, skipping run"
    else
      converge_by("Run task #{@current_resource}") do
        task_scheduler.activate(@current_resource.name)
        task_scheduler.run
      end
    end
  else
    Chef::Log.debug "Task #{@new_resource} doesn't exists, cannot run"
  end

end

action :change do
  if @current_resource.exists
    converge_by("Change task #{@current_resource}") do
      task_scheduler.activate(@current_resource.name)
      task_scheduler.application_name, task_scheduler.parameters = split_command(@new_resource.command) if @new_resource.command
      set_user_and_password
      save_task
    end
  else
    Chef::Log.debug "Task #{@new_resource} doesn't exists, nothing to change"
  end
end

action :delete do
  if @current_resource.exists
    converge_by("Delete task #{@current_resource}") do
      task_scheduler.delete(@current_resource.name)
    end
  else
    Chef::Log.debug "#{@current_resource} task doesn't exists - nothing to do"
  end
end

def load_current_resource
  @current_resource = Chef::Resource::WindowsTask.new(@new_resource.name)
  @current_resource.name(@new_resource.name)

  if task_scheduler.enum.include?("#{@current_resource.name}.job")
    task_scheduler.activate(@current_resource.name)
    @current_resource.exists = true
    @current_resource.status = :running if task_scheduler.status == "running"
    @current_resource.cwd(task_scheduler.working_directory)
    @current_resource.command("#{task_scheduler.application_name} #{task_scheduler.parameters}".strip)
    @current_resource.user(task_scheduler.account_information)
  end
end

protected

# Set user and password for task from @new_resource
def set_user_and_password
  if @new_resource.user && @new_resource.password
    if @new_resource.user == "SYSTEM"
      task_scheduler.set_account_information("", "")
    else
      task_scheduler.set_account_information(@new_resource.user, @new_resource.password)
    end
  elsif (@new_resource.user and !@new_resource.password) || (@new_resource.password and !@new_resource.user)
    Chef::Log.fatal "Must specify both user and password for task #{@new_resource.name}"
  else
    # "" is equal to SYSTEM account - but if you chage via api, you have set SYSTEM explicity
    # otherwise - for unknown reasons - it sets user to run task as to current user...
    task_scheduler.set_account_information("", "")
  end
end

# Save task back to .job file
def save_task
  task_scheduler.save
rescue ::Win32::TaskScheduler::Error => e
  Chef::Log.fatal "Failed to change task #{@new_resource.name}, error: #{e.message}"
end

# Return task scheduler api object
def task_scheduler
  gem "win32-taskscheduler", "0.2.2"
  require "win32/taskscheduler"
  @task_scheduler ||= ::Win32::TaskScheduler.new
end

# Tt splits command into application and parameters parts.
#
# Returns: array in form: [application_name, parameters]
def split_command(command)
  case command
  when /^['"](.+?)['"]\s+(.+)/ then [$1, $2] # command in quotation marks with params
  when /^(\S+)\s+(.+)/ then [$1, $2] # command without quotation marks with params
  else [command, ""] # in any other case - just command, without params
  end
end
