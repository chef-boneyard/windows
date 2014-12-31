#
# Author:: Seth Chisamore (<schisamo@opscode.com>)
# Copyright:: Copyright (c) 2011 Opscode, Inc
# License:: Apache License, Version 2.0
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

class WindowsRebootHandler < Chef::Handler
  include Chef::Mixin::ShellOut

  def initialize(allow_pending_reboots = true, timeout = 60, reason = "Opscode Chef initiated reboot")
    @allow_pending_reboots = allow_pending_reboots
    @timeout = timeout
    @reason = reason
  end

  def report
    log_message, reboot = begin
      if reboot_requested?
        ["chef_handler[#{self.class}] requested reboot will occur in #{timeout} seconds", true]
      elsif Windows::Helper.reboot_pending?
        if @allow_pending_reboots
          ["chef_handler[#{self.class}] reboot pending - automatic reboot will occur in #{timeout} seconds", true]
        else
          ["chef_handler[#{self.class}] reboot pending but handler not configured to act on pending reboots - please reboot node manually", false]
        end
      else
        ["chef_handler[#{self.class}] no reboot requested or pending", false]
      end
    end

    Chef::Log.warn(log_message)
    shell_out!("shutdown /r /t #{timeout} /c \"#{reason}\"") if reboot
  end

  private
  # reboot cause CHEF says so:
  # reboot explicitly requested in our cookbook code
  def reboot_requested?
    node.run_state[:reboot_requested] == true
  end

  def timeout
    node.run_state[:reboot_timeout] || node['windows']['reboot_timeout'] || @timeout
  end

  def reason
    node.run_state[:reboot_reason] || @reason
  end
end