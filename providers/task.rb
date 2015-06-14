#
# Author:: Paul Mooring (<paul@chef.io>)
# Cookbook Name:: windows
# Provider:: task
#
# Copyright:: 2012, Chef Software, Inc.
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

use_inline_resources

action :create do
  if @current_resource.exists && (not (task_need_update? || @new_resource.force))
    Chef::Log.info "#{@new_resource} task already exists - nothing to do"
  else
    validate_user_and_password
    validate_interactive_setting
    validate_create_day

    schedule  = @new_resource.frequency == :on_logon ? "ONLOGON" : @new_resource.frequency
    options = Hash.new
    options['F'] = '' if @new_resource.force || task_need_update?

    options['SC'] = schedule
    options['MO'] = @new_resource.frequency_modifier if allowed_frequency_modifier().include?(@new_resource.frequency)
    options['SD'] = @new_resource.start_day unless @new_resource.start_day.nil?
    options['ST'] = @new_resource.start_time unless @new_resource.start_time.nil?
    options['TR'] = "\"#{@new_resource.command}\" "
    options['RU'] = @new_resource.user
    options['RP'] = @new_resource.password if use_password?
    options['RL'] = 'HIGHEST' if @new_resource.run_level == :highest
    options['IT'] = '' if @new_resource.interactive_enabled
    options['D'] = @new_resource.day if @new_resource.day

    run_schtasks 'CREATE', options
    new_resource.updated_by_last_action true
    Chef::Log.info "#{@new_resource} task created"
  end
end

action :run do
  if @current_resource.exists
    if @current_resource.status == :running
      Chef::Log.info "#{@new_resource} task is currently running, skipping run"
    else
      run_schtasks 'RUN'
      new_resource.updated_by_last_action true
      Chef::Log.info "#{@new_resource} task ran"
    end
  else
    Chef::Log.debug "#{@new_resource} task doesn't exists - nothing to do"
  end
end

action :change do
  if @current_resource.exists
    validate_user_and_password
    validate_interactive_setting

    options = Hash.new
    options['TR'] = "\"#{@new_resource.command}\" " if @new_resource.command
    options['RU'] = @new_resource.user if @new_resource.user
    options['RP'] = @new_resource.password if @new_resource.password
    options['SD'] = @new_resource.start_day unless @new_resource.start_day.nil?
    options['ST'] = @new_resource.start_time unless @new_resource.start_time.nil?
    options['IT'] = '' if @new_resource.interactive_enabled

    run_schtasks 'CHANGE', options
    new_resource.updated_by_last_action true
    Chef::Log.info "Change #{@new_resource} task ran"
  else
    Chef::Log.debug "#{@new_resource} task doesn't exists - nothing to do"
  end
end

action :delete do
  if @current_resource.exists
	  # always need to force deletion
    run_schtasks 'DELETE', {'F' => ''}
    new_resource.updated_by_last_action true
    Chef::Log.info "#{@new_resource} task deleted"
  else
    Chef::Log.debug "#{@new_resource} task doesn't exists - nothing to do"
  end
end

action :end do
  if @current_resource.exists
    if @current_resource.status != :running
      Chef::Log.debug "#{@new_resource} is not running - nothing to do"
    else
      run_schtasks 'END'
      @new_resource.updated_by_last_action true
      Chef::Log.info "#{@new_resource} task ended"
    end
  else
    Chef::Log.fatal "#{@new_resource} task doesn't exist - nothing to do"
    raise Errno::ENOENT, "#{@new_resource}: task does not exist, cannot end"
  end
end

action :enable do
  if @current_resource.exists
    if @current_resource.enabled
      Chef::Log.debug "#{@new_resource} already enabled - nothing to do"
    else
      run_schtasks 'CHANGE', {'ENABLE' => ''}
      @new_resource.updated_by_last_action true
      Chef::Log.info "#{@new_resource} task enabled"
    end
  else
    Chef::Log.fatal "#{@new_resource} task doesn't exist - nothing to do"
    raise Errno::ENOENT, "#{@new_resource}: task does not exist, cannot enable"
  end
end

action :disable do
  if @current_resource.exists
    if @current_resource.enabled
      run_schtasks 'CHANGE', {'DISABLE' => ''}
      @new_resource.updated_by_last_action true
      Chef::Log.info "#{@new_resource} task disabled"
    else
      Chef::Log.debug "#{@new_resource} already disabled - nothing to do"
    end
  else
    Chef::Log.debug "#{@new_resource} task doesn't exist - nothing to do"
  end
end


def load_current_resource
  @current_resource = Chef::Resource::WindowsTask.new(@new_resource.name)
  @current_resource.task_name(@new_resource.task_name)


  pathed_task_name = @new_resource.task_name[0,1] == '\\' ? @new_resource.task_name : @new_resource.task_name.prepend('\\')
  task_hash = load_task_hash(@current_resource.task_name)
  if task_hash[:TaskName] == pathed_task_name
    @current_resource.exists = true
    if task_hash[:Status] == "Running"
      @current_resource.status = :running
    end
    if task_hash[:ScheduledTaskState] == "Enabled"
      @current_resource.enabled = true
    end
    allowed_frequency_modifier().each do |modifier|
      if task_hash[:ScheduleType].downcase.include? modifier.to_s
        @current_resource.frequency(modifier)
        break
      end
    end
    if @current_resource.frequency == :minute
      # hash output looks like this "0 Hour(s), 12 Minute(s)"
      @current_resource.frequency_modifier(task_hash[:"Repeat:Every"].split(',')[1].strip.split(' ')[0].to_i)
    elsif @current_resource.frequency == :hourly
      # hash output looks like this "12 Hour(s), 0 Minute(s)"
      @current_resource.frequency_modifier(task_hash[:"Repeat:Every"].split(',')[0].strip.split(' ')[0].to_i)
    elsif @current_resource.frequency == :daily
      # hash output looks like this "Every 3 day(s)"
      @current_resource.frequency_modifier(task_hash[:Days].split(' ')[1].to_i)
    elsif @current_resource.frequency == :weekly
      # hash output looks like this "Every 2 week(s)"
      @current_resource.frequency_modifier(task_hash[:Months].split(' ')[1].to_i)
    elsif @current_resource.frequency == :monthly
      # hash output looks like this "JUN, DEC"
      # not sure how to parse this easily yet so leaving it nil
      @current_resource.frequency_modifier(nil)
    end

    start_time_parts = task_hash[:StartTime].split(':')
    start_time_hour = start_time_parts[0].to_i
    if start_time_parts[2].include? 'p.m.'
      start_time_hour = start_time_parts[0].to_i + 12
    end
    start_time = start_time_hour.to_s.rjust(2, '0') + ':' + start_time_parts[1]
    @current_resource.start_time(start_time)
    @current_resource.cwd(task_hash[:Folder])
    @current_resource.command(task_hash[:TaskToRun])
    @current_resource.user(task_hash[:RunAsUser])
  end if task_hash.respond_to? :[]
end

private
def run_schtasks(task_action, options={})
  cmd = "schtasks /#{task_action} /TN \"#{@new_resource.task_name}\" "
  options.keys.each do |option|
    cmd += "/#{option} #{options[option]} "
  end
  Chef::Log.debug("running: ")
  Chef::Log.debug("    #{cmd}")
  shell_out!(cmd, {:returns => [0]})
end

def task_need_update?
  @current_resource.command != @new_resource.command ||
    @current_resource.user != @new_resource.user ||
      @current_resource.frequency != @new_resource.frequency ||
        ( (@current_resource.frequency_modifier != @new_resource.frequency_modifier) &&
          @current_resource != :monthly) ||
            @current_resource.start_time != @new_resource.start_time
end

def load_task_hash(task_name)
  Chef::Log.debug "looking for existing tasks"

  # we use shell_out here instead of shell_out! because a failure implies that the task does not exist
  output = shell_out("schtasks /Query /FO LIST /V /TN \"#{task_name}\"").stdout
  if output.empty?
    task = false
  else
    task = Hash.new
    output.split("\n").map! do |line|
      split_line = [line.slice(0..37), line.slice(37..-1)]
      line = [split_line[0].rpartition(':')[0], split_line[1] || ""]
      line.map! do |field|
        field.strip
      end
    end.each do |field|
      if field.kind_of? Array and field[0].respond_to? :to_sym
        task[field[0].gsub(/\s+/,"").to_sym] = field[1]
      end
    end
  end

  task
end

SYSTEM_USERS = ['NT AUTHORITY\SYSTEM', 'SYSTEM', 'NT AUTHORITY\LOCALSERVICE', 'NT AUTHORITY\NETWORKSERVICE']

def validate_user_and_password
  if @new_resource.user && use_password?
    if @new_resource.password.nil?
      Chef::Log.fatal "#{@new_resource.task_name}: Can't specify a non-system user without a password!"
    end
  end

end

def validate_interactive_setting
  if @new_resource.interactive_enabled && password.nil?
    Chef::Log.fatal "#{new_resource} did not provide a password when attempting to set interactive/non-interactive."
  end
end

def validate_create_day
  if not @new_resource.day then
    return
  end
  if not [:weekly, :monthly].include?(@new_resource.frequency) then
    raise "day attribute is only valid for tasks that run weekly or monthly"
  end
  if @new_resource.day.is_a? String then
    days = @new_resource.day.split(",")
    days.each do |day|
      if not ["mon", "tue", "wed", "thu", "fri", "sat", "sun", "*"].include?(day.strip.downcase) then
        raise "day attribute invalid.  Only valid values are: MON, TUE, WED, THU, FRI, SAT, SUN and *.  Multiple values must be separated by a comma."
      end
    end
  end
end

def use_password?
  @use_password ||= !SYSTEM_USERS.include?(@new_resource.user.upcase)
end

def allowed_frequency_modifier
  [:minute, :hourly, :daily, :weekly, :monthly]
end