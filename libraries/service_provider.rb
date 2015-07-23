#
# Author:: Andrey Rotchev (<arotchev@wildapricot.com>)
# Cookbook Name:: windows
# Provider:: service
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

require 'chef/provider/service/windows'
require 'chef/win32/error'
require 'win32/service'

class Chef::Provider::WindowsCookbookService < Chef::Provider::Service::Windows

  ALLOWED_STARTUP_TYPES = { :automatic => Win32::Service::AUTO_START,
                            :manual    => Win32::Service::DEMAND_START,
                            :disabled  => Win32::Service::DISABLED }

  ALLOWED_FAILURE_ACTIONS = { :run => Win32::Service::ACTION_NONE,
                              :reboot    => Win32::Service::ACTION_REBOOT,
                              :restart    => Win32::Service::ACTION_RESTART,
                              :run_command  => Win32::Service::ACTION_RUN_COMMAND }

  def load_current_resource
    @current_resource = Chef::Resource::WindowsCookbookService.new(@new_resource.name, nil)
    @current_resource.service_name(@new_resource.service_name)

    if Win32::Service.exists?(@new_resource.service_name)
      @current_resource.exist(true)
      @current_resource.enabled(current_start_type != DISABLED)
      @current_resource.running(current_state == RUNNING)
      @current_resource.configured(config_same?)
    else
      @current_resource.exist(false)
      @current_resource.enabled(false)
      @current_resource.running(false)
      @current_resource.configured(false)
    end
    Chef::Log.debug "Resource #{@new_resource.service_name} exist: #{@current_resource.exist}, enabled: #{@current_resource.enabled},
                    running: #{@current_resource.running}, configured: #{@current_resource.configured}"
    @current_resource
  end

  def action_create
    if Win32::Service.exists?(@new_resource.service_name)
      Chef::Log.warn("service #{@new_resource.service_name} already exists")
    else
      Chef::Log.info("createing win service #{@new_resource.service_name}")
      Win32::Service::create(fill_config_hash)
      Chef::Log.debug("#{@new_resource.service_name} created")
      @new_resource.updated_by_last_action(true)
    end
    load_new_resource_state
    @new_resource.exist(true)
    @new_resource.configured(true)
  end

  def action_config
    #check: can service be configured in runtime?
    if Win32::Service.exists?(@new_resource.service_name)
      if config_same?
        Chef::Log.info("#{@new_resource.service_name}: config the same, nothing todo")
      else
        Chef::Log.info("configuring win service #{@new_resource.service_name}")
        Win32::Service.configure(fill_config_hash)
        Chef::Log.debug("#{@new_resource.service_name} configured")
        @new_resource.updated_by_last_action(true)
      end
    else
      Chef::Log.error("Cannot configure service #{@new_resource.service_name}. It's not exist")
    end
    load_new_resource_state
    @new_resource.configured(true)
    @new_resource.enabled(nil)
  end

  def action_delete
    #check: is it possible to delete service while it's running?
    if Win32::Service.exists?(@new_resource.service_name)
      Win32::Service.delete(@new_resource.service_name, @new_resource.host)
      Chef::Log.info("Service #{@new_resource.service_name} was deleted")
      @new_resource.updated_by_last_action(true)
    else
      Chef::Log.warn("service #{@new_resource.service_name} not exist, nothing to delete")
    end
    load_new_resource_state
    @new_resource.exist(false)
    @new_resource.enabled(nil)
    @new_resource.running(nil)
  end

  private
  def config_same?
    current_config = Win32::Service.config_info(@new_resource.service_name)

    #should check all parameters configuring (look at full_config_hash)
    
    Chef::Log.debug("Config same?. @new_resource.startup_type.nil?: #{@new_resource.startup_type.nil?}  current.start_type: #{current_config.start_type}, new.startup_type: #{Win32::Service.get_start_type(ALLOWED_STARTUP_TYPES[@new_resource.startup_type])}")
    Chef::Log.debug("Config same?. @new_resource.bin_path.nil?: #{@new_resource.bin_path.nil?} current.bin_path: #{current_config.binary_path_name}, new.bin_path: #{@new_resource.bin_path}")
    Chef::Log.debug("Config same?. @new_resource.run_as_user.nil?: #{@new_resource.run_as_user.nil?} current.run_as_user: #{current_config.service_start_name}, new.run_as_user: #{@new_resource.run_as_user}")
    Chef::Log.debug("Config same?. @new_resource.display_name.nil?: #{@new_resource.display_name.nil?} current.display_name: #{current_config.display_name}, new.display_name: #{@new_resource.display_name}")
    (@new_resource.startup_type.nil? ||
        current_config.start_type == Win32::Service.get_start_type(ALLOWED_STARTUP_TYPES[@new_resource.startup_type])) &&
        (@new_resource.bin_path.nil? ||
            current_config.binary_path_name == @new_resource.bin_path) &&
        (@new_resource.run_as_user.nil? ||
            current_config.service_start_name == @new_resource.run_as_user) &&
        (@new_resource.display_name.nil? ||
            current_config.display_name == @new_resource.display_name)
  end

  def fill_config_hash
    {
        :service_name         => @new_resource.service_name,
        :display_name         => @new_resource.display_name,
        :description          => @new_resource.description,
        :binary_path_name     => @new_resource.bin_path,
        :service_start_name   => @new_resource.run_as_user,
        :password             => @new_resource.run_as_password,
        :failure_reset_period => @new_resource.reset_fail_counter_days*60*60*24,
        :failure_delay        => @new_resource.restart_after_min*60*1000,
        :failure_actions      => get_failure_actions,
        :start_type           => ALLOWED_STARTUP_TYPES[@new_resource.startup_type],
        :host                 => @new_resource.host,

        :service_type         => Win32::Service::WIN32_OWN_PROCESS,
        :error_control        => Win32::Service::ERROR_NORMAL,
    }
  end

  def get_failure_actions
    actions = [
        ALLOWED_FAILURE_ACTIONS[@new_resource.recovery_first_failure],
        ALLOWED_FAILURE_ACTIONS[@new_resource.recovery_second_failure],
        ALLOWED_FAILURE_ACTIONS[@new_resource.recovery_subsequent_failures]
    ]
    Chef::Log.debug("failure actions: #{actions}")
    actions
  end

  def load_new_resource_state
    # If the user didn't specify a change in enabled state,
    # it will be the same as the old resource
    if @new_resource.exist.nil?
      @new_resource.exist(@current_resource.exist)
    end
    if @new_resource.enabled.nil?
      @new_resource.enabled(@current_resource.enabled)
    end
    if @new_resource.running.nil?
      @new_resource.running(@current_resource.running)
    end
    if @new_resource.configured.nil?
      @new_resource.configured(@current_resource.configured)
    end
  end
end