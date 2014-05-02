#
# Author:: Blair Hamilton (<blairham@me.com>)
# Cookbook Name:: windows
# Provider:: path
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

action :add do
	unless @new_resource.created
		cmd = "netsh advfirewall firewall add rule #{@new_resource.group ? 'Group' : 'Name'}=\"#{@new_resource.rule_name}\""
		cmd += " Dir=\"#{@new_resource.direction.to_s}\"" unless @new_resource.direction.nil?
		cmd += " Action=\"#{@new_resource.firewall_action.to_s}\"" unless @new_resource.firewall_action.nil?
		cmd += " Protocol=\"#{@new_resource.protocol.to_s}\"" unless @new_resource.protocol.nil?
		cmd += " Enable=\"#{@new_resource.enable.to_s}\"" unless @new_resource.enable.nil?
		cmd += " Profile=\"#{@new_resource.profile.join(",")}\"" unless @new_resource.profile.nil?
		cmd += " Localport=#{@new_resource.ports.join(",")}" unless @new_resource.ports.nil?

		Chef::Log.info "Adding #{@new_resource.rule_name}"
		Chef::Log.debug(cmd)
		shell_out!(cmd)
	else
		Chef::Log.info "#{@new_resource.rule_name} already exists"
	end
end

action :set do
	if @new_resource.created
		cmd = "netsh advfirewall firewall set rule #{@new_resource.group ? 'Group' : 'Name'}=\"#{@new_resource.rule_name}\""
		cmd += " new"
		cmd += " Enable=\"#{@new_resource.enable.to_s}\"" unless @new_resource.enable.nil?
		cmd += " Dir=\"#{@new_resource.direction.to_s}\"" unless (@new_resource.direction.nil? || @new_resource.group)
		cmd += " Action=\"#{@new_resource.firewall_action.to_s}\"" unless (@new_resource.firewall_action.nil? || @new_resource.group)
		cmd += " Protocol=\"#{@new_resource.protocol.to_s}\"" unless (@new_resource.protocol.nil? || @new_resource.group)
		cmd += " Profile=\"#{@new_resource.profile.join(",")}\"" unless (@new_resource.profile.nil? || @new_resource.group)
		cmd += " Localport=#{@new_resource.ports.join(",")}" unless (@new_resource.ports.nil? || @new_resource.group)

		Chef::Log.info "Updating #{@new_resource.rule_name}"
		Chef::Log.debug(cmd)
		shell_out!(cmd)
	else
		Chef::Log.info "#{@new_resource.rule_name} does not exist"
	end
end

action :delete do
	if @new_resource.created
		cmd = "netsh advfirewall firewall delete rule #{@new_resource.group ? 'Group' : 'Name'}=\"#{@new_resource.rule_name}\""
		cmd += " Dir=\"#{@new_resource.direction.to_s}\"" unless @new_resource.direction.nil?
		cmd += " Protocol=\"#{@new_resource.protocol.to_s}\"" unless @new_resource.protocol.nil?
		cmd += " Localport=#{@new_resource.ports.join(",")}" unless @new_resource.ports.nil?

		Chef::Log.info "Deleting #{@new_resource.rule_name}"
		Chef::Log.debug(cmd)
		shell_out!(cmd)
	else
		Chef::Log.info "#{@new_resource.rule_name} does not exist"
	end
end

def load_current_resource
	unless @new_resource.group
		show_rule_cmd = "netsh advfirewall firewall show rule Name=\"#{@new_resource.rule_name}\""
		cmd = shell_out("#{show_rule_cmd}", { :returns => [0] })
		if (cmd.stderr.empty? && (cmd.stdout =~ /^.*Rule Name.*$/i))
			@new_resource.created = true
		end
	else
		@new_resource.created = true
	end
end