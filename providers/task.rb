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
    if @new_resource.user and @new_resource.password.nil? then Chef::Log.debug "#{@new_resource} did not specify a password, creating task without a password" end
    validate_create_frequency_modifier
    validate_create_day
    validate_create_months
    use_force = @new_resource.force ? '/F' : ''
    cmd =  "schtasks /Create #{use_force} /TN \"#{@new_resource.name}\" "
    schedule  = @new_resource.frequency == :on_logon ? "ONLOGON" : @new_resource.frequency
    cmd += "/SC #{schedule} "
    cmd += "/MO #{@new_resource.frequency_modifier} " if [:minute, :hourly, :daily, :weekly, :monthly].include?(@new_resource.frequency)
    cmd += "/SD \"#{@new_resource.start_day}\" " unless @new_resource.start_day.nil?
    cmd += "/ST \"#{@new_resource.start_time}\" " unless @new_resource.start_time.nil?
    cmd += "/TR \"#{@new_resource.command}\" "
    cmd += "/RU \"#{@new_resource.user}\" " if @new_resource.user
    cmd += "/RP \"#{@new_resource.password}\" " if @new_resource.user and @new_resource.password
    cmd += "/RL HIGHEST " if @new_resource.run_level == :highest
    if @new_resource.day then
      cmd += "/D \"#{@new_resource.day}\" "
    end
    cmd += "/M \"#{@new_resource.months}\" " unless @new_resource.months.nil?
    shell_out!(cmd, {:returns => [0]})
    new_resource.updated_by_last_action true
    Chef::Log.info "#{@new_resource} task created"
  end
end

action :run do
  if @current_resource.exists
    if @current_resource.status == :running
      Chef::Log.info "#{@new_resource} task is currently running, skipping run"
    else
      cmd = "schtasks /Run /TN \"#{@current_resource.name}\""
      shell_out!(cmd, {:returns => [0]})
      new_resource.updated_by_last_action true
      Chef::Log.info "#{@new_resource} task ran"
    end
  else
    Chef::Log.debug "#{@new_resource} task doesn't exists - nothing to do"
  end
end

action :change do
  if @current_resource.exists
    cmd =  "schtasks /Change /TN \"#{@current_resource.name}\" "
    cmd += "/TR \"#{@new_resource.command}\" " if @new_resource.command
    if @new_resource.user && @new_resource.password
      cmd += "/RU \"#{@new_resource.user}\" /RP \"#{@new_resource.password}\" "
    elsif (@new_resource.user and !@new_resource.password) || (@new_resource.password and !@new_resource.user)
      Chef::Log.fatal "#{@new_resource.name}: Can't specify user or password without both!"
    end
    shell_out!(cmd, {:returns => [0]})
    new_resource.updated_by_last_action true
    Chef::Log.info "Change #{@new_resource} task ran"
  else
    Chef::Log.debug "#{@new_resource} task doesn't exists - nothing to do"
  end
end

action :delete do
  if @current_resource.exists
    use_force = @new_resource.force ? '/F' : ''
    cmd = "schtasks /Delete #{use_force} /TN \"#{@current_resource.name}\""
    shell_out!(cmd, {:returns => [0]})
    new_resource.updated_by_last_action true
    Chef::Log.info "#{@new_resource} task deleted"
  else
    Chef::Log.debug "#{@new_resource} task doesn't exists - nothing to do"
  end
end

action :enable do
  if @current_resource.exists
    if @current_resource.enabled
      Chef::Log.debug "#{@new_resource} already enabled - nothing to do"
    else
      cmd =  "schtasks /Change /TN \"#{@current_resource.name}\" "
      cmd += "/ENABLE"
      shell_out!(cmd, {:returns => [0]})
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
      cmd =  "schtasks /Change /TN \"#{@current_resource.name}\" "
      cmd += "/DISABLE"
      shell_out!(cmd, {:returns => [0]})
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
  @current_resource.name(@new_resource.name)

  task_hash = load_task_hash(@current_resource.name)
  if task_hash[:TaskName] == '\\' + @new_resource.name
    @current_resource.exists = true
    if task_hash[:Status] == "Running"
      @current_resource.status = :running
    end
    if task_hash[:ScheduledTaskState] == "Enabled"
      @current_resource.enabled = true
    end
    @current_resource.cwd(task_hash[:Folder])
    @current_resource.command(task_hash[:TaskToRun])
    @current_resource.user(task_hash[:RunAsUser])
  end if task_hash.respond_to? :[]
end

private

def load_task_hash(task_name)
  Chef::Log.debug "looking for existing tasks"

  # we use shell_out here instead of shell_out! because a failure implies that the task does not exist
  output = shell_out("schtasks /Query /FO LIST /V /TN \"#{task_name}\"").stdout
  if output.empty?
    task = false
  else
    task = Hash.new

    output.split("\n").map! do |line|
      line.split(":", 2).map! do |field|
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

def validate_create_months 
  unless @new_resource.months
    return
  end

  unless :monthly === new_resource.frequency 
    raise "'months' attribute is only valid for tasks that run monthly"
  end

  months = @new_resource.months.split(",")
  months.each do |month|
    unless ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC", "*"].include?(month.upcase) 
      raise "'months' attribute is invalid.  Only valid values are: JAN, FEB, MAR, APR, MAY, JUN, JUL, AUG, SEP, OCT, NOV, DEC and Wildcard '*'.  Multiple values must be separated by a comma."
    end
  end
end

def validate_create_frequency_modifier 
  unless @new_resource.frequency.nil? || @new_resource.frequency_modifier.nil?
    case @new_resource.frequency
    when :minute
      unless @new_resource.frequency_modifier.to_i > 0 && @new_resource.frequency_modifier.to_i <= 1439
        raise "'frequency_modifier' value #{@new_resource.frequency_modifier} is invalid.  Valid values for :minute frequency are 1 - 1439."
      end
    when :hourly
      unless @new_resource.frequency_modifier.to_i > 0 && @new_resource.frequency_modifier.to_i <= 23
        raise "'frequency_modifier' value #{@new_resource.frequency_modifier} is invalid.  Valid values for :hourly frequency are 1 - 23."
      end
    when :daily
      unless @new_resource.frequency_modifier.to_i > 0 && @new_resource.frequency_modifier.to_i <= 365
        raise "'frequency_modifier' value #{@new_resource.frequency_modifier} is invalid.  Valid values for :daily frequency are 1 - 365."
      end
    when :weekly
      unless @new_resource.frequency_modifier.to_i > 0 && @new_resource.frequency_modifier.to_i <= 52
        raise "'frequency_modifier' value #{@new_resource.frequency_modifier} is invalid.  Valid values for :weekly frequency are 1 - 52."
      end
    when :monthly
      unless ('1'..'12').to_a.push('FIRST', 'SECOND', 'THIRD', 'FOURTH', 'LAST', 'LASTDAY').include?(@new_resource.frequency_modifier.to_s.upcase)
        raise "'frequency_modifier' value #{@new_resource.frequency_modifier} is invalid.  Valid values for :monthly frequency are 1 - 12, 'FIRST', 'SECOND', 'THIRD', 'FOURTH', 'LAST', 'LASTDAY'."
      end
    else
      # Currently is handled in create action '/MO' line. Does not allow for frequency_modifier for once,onstart,onlogon,onidle
      # Note that 'OnEvent' is not a supported frequency.
    end
  end
end
