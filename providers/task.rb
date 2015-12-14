#
# Author:: Paul Mooring (<paul@chef.io>)
# Cookbook Name:: windows
# Provider:: task
#
# Copyright:: 2012-2015, Chef Software, Inc.
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

use_inline_resources

def whyrun_supported?
  true
end

action :create do
  create_or_update_task :create
end

action :run do
  windows_advanced_task new_resource.task_name do
    action :start
  end
end

action :change do
  create_or_update_task :update
end

action :delete do
  windows_advanced_task new_resource.task_name do
    action :delete
  end
end

action :end do
  windows_advanced_task new_resource.task_name do
    action :stop
  end
end

action :enable do
  windows_advanced_task new_resource.task_name do
    action :enable
  end
end

action :disable do
  windows_advanced_task new_resource.task_name do
    action :disable
  end
end

private

DAYS_VALUE = %w(SUN MON TUE WED THU FRI SAT)
MONTHS_VALUE = %w(JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC)

TRIGGER_MAP = { once: :time, minute: :time, hourly: :time, on_logon: :logon, onstart: :boot, on_idle: :idle }

def formated_start_boundary
  day = new_resource.start_day || DateTime.now.strftime('%d/%m/%Y')
  time = new_resource.start_time || DateTime.now.strftime('%H:%M')

  DateTime.strptime("#{day} #{time}", '%d/%m/%Y %H:%M').strftime('%Y-%m-%dT%H:%M:%S')
end

def create_or_update_task(chef_action)
  # can't call below helpers from the windows_advanced_task block
  trigger = compute_trigger
  logon_type = compute_logon_type
  exec_action = compute_exec_action

  windows_advanced_task new_resource.task_name do
    action        chef_action
    exec_actions  exec_action
    force         new_resource.force
    logon_type    logon_type
    password      new_resource.password if [:interactive_token_or_password, :password].include?(logon_type)
    run_level     new_resource.run_level
    triggers      trigger
    user          new_resource.user
  end
end

def compute_exec_action
  # Splits path and arguments from given command
  if new_resource.command.include? '\"'
    Chef::Log.warn "#{new_resource} has escaped command: `#{new_resource.command}'"
    if new_resource.unescape_command
      new_resource.command new_resource.command.gsub '\"', '"'
      Chef::Log.warn "#{new_resource} command has been unescaped automaticaly, use the `unescape_command' windows_task's attribute to control this behavior"
    end
  end
  path, args = new_resource.command.match(/("[^"]+"|[^"\s]+)\s*(.*)/).captures
  Windows::TaskSchedulerHelper.new_ole_hash :exec_action, 'Arguments' => args, 'Path' => path, 'WorkingDirectory' => new_resource.cwd
end

def compute_day_of_week_value(days)
  fail "Invalid day attribute, valid values are: #{DAYS_VALUE.join ', '} and *. Multiple values must be separated by a comma." unless days.is_a? String

  if days == '*'
    # '*' means all days
    2**DAYS_VALUE.size - 1
  else
    days.upcase.split(',').inject(0) do |mask, day|
      idx = DAYS_VALUE.index(day)
      fail "Invalid day attribute, valid values are: #{DAYS_VALUE.join ', '} and *. Multiple values must be separated by a comma." unless idx
      mask | 2**idx
    end
  end
end

def compute_month_of_year_value(months)
  if months == '*'
    # '*' means all months
    2**MONTHS_VALUE.size - 1
  else
    months.upcase.split(',').inject(0) do |mask, month|
      idx = MONTHS_VALUE.index(month)
      fail "Invalid months attribute, valid values are: #{MONTHS_VALUE.join ', '} and *. Multiple values must be separated by a comma." unless idx
      mask | 2**idx
    end
  end
end

def compute_logon_type
  if Windows::TaskSchedulerHelper::SERVICE_USERS.include?(@new_resource.user.upcase)
    :service_account
  else
    fail 'Password is mandatory when using interactive mode or non-system user!' if new_resource.password.nil?
    new_resource.interactive_enabled ? :interactive_token_or_password : :password
  end
end

def compute_trigger
  fail 'Days should only be used with weekly or monthly frequency' if new_resource.day && [:weekly, :monthly].include?(new_resource.frequency)

  {}.tap do |trigger|
    # Format StartBoundary if start_day or start_time is provided
    trigger['StartBoundary'] = formated_start_boundary unless new_resource.start_day.nil? && new_resource.start_time.nil?

    # Converts frequency to advanced_task trigger type
    trigger['Type'] = TRIGGER_MAP[new_resource.frequency] || new_resource.frequency

    case new_resource.frequency
    when :daily then trigger['DaysInterval'] = new_resource.frequency_modifier
    when :hourly then trigger['Repetition'] = { 'Interval' => "PT#{new_resource.frequency_modifier}H" }
    when :minute then trigger['Repetition'] = { 'Interval' => "PT#{new_resource.frequency_modifier}M" }
    when :on_logon then trigger['UserId'] = new_resource.user
    when :weekly
      trigger['WeeksInterval'] = new_resource.frequency_modifier
      trigger['DaysOfWeek'] = compute_day_of_week_value(new_resource.day)
    when :monthly
      fail 'Invalid day attribute, it must be an integer between 1 and 31' unless new_resource.day.is_a?(Integer) && new_resource.day.between?(1, 31)

      trigger['DaysInterval'] = new_resource.frequency_modifier
      trigger['DaysOfMonth'] = new_resource.day
      trigger['MonthsOfYear'] = compute_month_of_year_value(new_resource.months)
    end
  end
end
