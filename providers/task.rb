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

action :create do
  has_changed = nil
  if @current_resource.exists
    has_changed = existing_task_different_from_expected_one()
    if has_changed
      Chef::Log.info "#{@new_resource} task already exists but with another definition"
    else
      Chef::Log.info "#{@new_resource} task already exists - nothing to do"
    end
  end

  if !@current_resource.exists || (has_changed && @new_resource.force)
    if @new_resource.user and @new_resource.password.nil? then Chef::Log.debug "#{@new_resource} did not specify a password, creating task without a password" end
    use_force = @new_resource.force ? '/F' : ''
    cmd =  "schtasks /Create #{use_force} /TN \"#{@new_resource.name}\" "
    schedule  = @new_resource.frequency == :on_logon ? "ONLOGON" : @new_resource.frequency
    cmd += "/SC #{schedule} "
    cmd += "/MO #{@new_resource.frequency_modifier} " if [:minute, :hourly, :daily, :weekly, :monthly].include?(@new_resource.frequency)
    cmd += "/SD \"#{@new_resource.start_day}\" " unless @new_resource.start_day.nil?
    cmd += "/ST \"#{@new_resource.start_time}\" " unless @new_resource.start_time.nil?
    command = @new_resource.command.gsub(/["\\]/,'\\\\\0') # Escapes double quotes and backslashes
    cmd += "/TR \"#{command}\" "
    cmd += "/RU \"#{@new_resource.user}\" " if @new_resource.user
    cmd += "/RP \"#{@new_resource.password}\" " if @new_resource.user and @new_resource.password
    cmd += "/RL HIGHEST " if @new_resource.run_level == :highest
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

def existing_task_different_from_expected_one
  if @current_resource.command != @new_resource.command
    Chef::Log.debug "#{@new_resource} task already exists but doesn't have the expected command"
    return true
  end

  # On Windows, logins are not case-sensitive
  if @current_resource.user.downcase != @new_resource.user.downcase
    Chef::Log.debug "#{@new_resource} task already exists but doesn't have the expected user"
    return true
  end
  return false
end
